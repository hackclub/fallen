# One session of work on a Project. Lives twice: here, and as a reply in the project's Slack thread.
# `slack_ts` is the reply's timestamp, whichever side it was written on. `source` says where it was written.
# A journal written in Slack can span several replies (JournalDraft); `slack_parts` keeps each one's ts and
# text, so editing or deleting any of them in Slack updates the body.
# == Schema Information
#
# Table name: journals
#
#  id                  :bigint           not null, primary key
#  body                :text             not null
#  discarded_at        :datetime
#  duration_minutes    :integer
#  hours_self_claimed  :boolean
#  lapse_url           :string
#  slack_parts         :jsonb            not null
#  slack_posted_by_bot :boolean          default(FALSE), not null
#  slack_ts            :string
#  source              :string           default("web"), not null
#  tracked_minutes     :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  project_id          :bigint           not null
#  slack_channel_id    :string
#  user_id             :bigint           not null
#
# Indexes
#
#  index_journals_needing_hours                     (project_id) WHERE ((discarded_at IS NULL) AND (duration_minutes IS NULL))
#  index_journals_on_created_at                     (created_at)
#  index_journals_on_discarded_at                   (discarded_at)
#  index_journals_on_project_id                     (project_id)
#  index_journals_on_slack_channel_id_and_slack_ts  (slack_channel_id,slack_ts) UNIQUE WHERE (slack_ts IS NOT NULL)
#  index_journals_on_slack_parts                    (slack_parts jsonb_path_ops) USING gin
#  index_journals_on_user_id                        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class Journal < ApplicationRecord
  include PublicIdentifiable
  include Discardable

  SOURCES = %w[web slack transfer].freeze
  MAX_MINUTES = 24 * 60
  # Every two hours logged need a photo to show for them.
  MINUTES_PER_IMAGE = 120
  MAX_TIMELAPSES = 10
  # A journal of up to an hour needs this much writing for a reviewer to follow what was done. Past that it needs
  # more for every two hours logged, rounded up. Photos embedded in it don't count.
  MIN_BODY_LENGTH = 100
  BODY_LENGTH_PER_TWO_HOURS = 200
  MAX_BODY_LENGTH = 10_000
  # Hours are typed to two decimals, so taking the tracked time as offered can land a minute over it.
  CLAIM_LEEWAY = 1

  set_public_id_prefix :jrn
  # Replaced by lapse_timelapses.journal_id so a journal can have several. Drop the column once this is deployed.
  self.ignored_columns += %w[lapse_timelapse_id]
  has_paper_trail

  belongs_to :project
  belongs_to :user
  # Timelapses picked from the person's Lapse account. Their recorded time adds up to the journal's hours; nothing
  # typed counts while there are any.
  has_many :lapse_timelapses, dependent: :nullify
  has_one :xp_entry, -> { where(kind: "journal") }, as: :source
  has_many_attached :images

  # Photos still being copied over from Slack (CollectSlackJournalJob), counted before they arrive.
  attr_accessor :incoming_images
  # Set by JournalsController: an edit made on the site, whichever side the journal was first written on.
  attr_accessor :edited_on_site

  IMAGE_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  MAX_IMAGES = 10
  MAX_IMAGE_BYTES = 10.megabytes
  # Blob metadata UploadsController sets to who uploaded it.
  UPLOADER_KEY = "uploaded_by"
  # A photo embedded by the editor: `![alt](/rails/active_storage/blobs/redirect/<signed id>/<filename>)`.
  EMBEDDED_IMAGE = /!\[[^\]]*\]\(\s*<?([^)\s>]*)/
  PHOTO_PATH = %r{\A/rails/active_storage/blobs/redirect/([^/]+)/}

  validates :body, presence: true, length: { maximum: MAX_BODY_LENGTH }
  # New journals, and edits on the site. Edits made in Slack always go through, so the journal keeps up with the
  # thread.
  # Transferred journals (ProjectTransfer) are copied as they were written in the other program, photos as links.
  validate :body_long_enough, if: -> { !transferred? && (new_record? || (will_save_change_to_body? && (from_web? || edited_on_site))) }
  validates :source, inclusion: { in: SOURCES }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :duration_minutes, numericality: { less_than_or_equal_to: MAX_MINUTES }, allow_nil: true, unless: :transferred?
  validates :slack_ts, uniqueness: { scope: :slack_channel_id }, allow_nil: true
  # Only on journals from before timelapses were picked from Lapse; nothing sets it any more, since a typed link
  # could point anywhere.
  validates :lapse_url, format: { with: %r{\Ahttps://\S+\z}, message: "must be a link starting with https://" }, allow_blank: true
  # Only new ones: someone who has left the team can still edit and delete what they wrote.
  validate :author_on_team, on: :create
  validate :images_are_images
  validate :images_are_new_uploads, if: -> { attachment_changes.key?("images") }
  validate :embeds_only_own_photos, if: -> { (from_web? || edited_on_site || transferred?) && (new_record? || will_save_change_to_body?) }
  validate :images_cover_hours, if: -> { !transferred? && (new_record? || duration_minutes_changed? || attachment_changes.key?("images")) }
  validate :duration_was_understood, unless: :transferred?
  validate :picked_timelapses_are_usable, if: -> { @picked_timelapses }
  validate :hours_unchanged, on: :update

  before_validation :take_hours_from_lapse
  before_validation :snapshot_tracked_time, on: :create, unless: :transferred?
  before_save -> { @attached_images = attachment_changes["images"]&.attachments&.select(&:new_record?) }
  before_save :mark_self_claimed, if: -> { new_record? || duration_minutes_changed? || @picked_timelapses }

  after_save :claim_picked_timelapses, if: -> { @picked_timelapses }
  # A transfer's XP is the amount its reviewer set, so its journals earn none themselves.
  after_create -> { XpEntry.grant_stupendous(self) }, unless: :transferred?
  after_save :sync_xp, if: -> { !transferred? && (saved_change_to_duration_minutes? || saved_change_to_discarded_at?) }
  # A new journal starts the pet's timer from zero; deleting the newest one brings its time back.
  after_commit -> { TimerChannel.changed(user_id) }, if: -> { previous_changes.key?("id") || previous_changes.key?("discarded_at") }
  after_commit :analyze_images_later, if: -> { @attached_images.present? }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  # Transferred journals can't be edited, and one given no share of a transfer's hours has none to add.
  scope :needing_hours, -> { where(duration_minutes: nil).where.not(source: "transfer") }
  # Transferred journals are dated when they were written in another program, so activity over time leaves them out.
  scope :written_here, -> { where.not(source: "transfer") }

  def self.find_by_slack_message(channel_id, ts)
    return nil if channel_id.blank? || ts.blank?

    where(slack_channel_id: channel_id).where("slack_ts = :ts OR slack_parts @> CAST(:part AS jsonb)", ts: ts, part: [ { ts: ts } ].to_json).first
  end

  # Photos are the proof of the work, so each is attached once, by someone it belongs to: a signed id seen on
  # another journal or a banner, even one's own, is refused. `blobs` are the ones being newly attached; ones built
  # from bytes just now (Slack photos) have nothing to check. Blobs uploaded before uploads were tagged have no
  # uploader.
  def self.reused_uploads?(blobs, uploaders:, record:)
    stored = blobs.select(&:persisted?)
    return false if stored.empty?

    stored.any? { |blob| !blob.metadata.fetch(UPLOADER_KEY, uploaders.first).in?(uploaders) } ||
      ActiveStorage::Attachment.where(blob_id: stored.map(&:id)).where.not(record_type: record.class.name, record_id: record.id).exists?
  end

  def self.body_from(parts) = parts.map { |part| part["text"] }.compact_blank.join("\n\n")

  def from_slack? = source == "slack"
  def from_web? = source == "web"
  def transferred? = source == "transfer"
  def on_slack? = slack_channel_id.present? && slack_ts.present?
  def slack_url = on_slack? ? SlackMessaging.permalink(slack_channel_id, slack_ts, thread_ts: project.slack_thread_ts) : nil
  def hours_logged? = duration_minutes.present?
  def xp = xp_entry&.kept? ? xp_entry.amount : nil
  def images_needed = (duration_minutes.to_f / MINUTES_PER_IMAGE).ceil
  def duration_text = Duration.format(duration_minutes)

  # How much writing there is, leaving out embedded photos (Markdown images).
  def self.written_text(text) = text.to_s.gsub(/!\[[^\]]*\]\([^)]*\)/, "").strip
  def self.written_length(text) = written_text(text).length
  def self.body_length_needed(minutes) = minutes.to_i <= 60 ? MIN_BODY_LENGTH : (minutes.to_i / 120.0).ceil * BODY_LENGTH_PER_TWO_HOURS
  def multi_part? = slack_parts.size > 1
  def last_slack_ts = slack_parts.last&.dig("ts") || slack_ts

  # The full set of timelapses the journal should end up with, saved along with it.
  def picked_timelapses=(timelapses)
    @picked_timelapses = timelapses.to_a
  end

  def slack_message_edited(ts, text)
    return update(body: text) if slack_parts.empty?

    parts = slack_parts.map { |part| part["ts"] == ts ? part.merge("text" => text) : part }
    update(slack_parts: parts, body: Journal.body_from(parts)) unless parts == slack_parts
  end

  def slack_message_deleted(ts)
    parts = slack_parts.reject { |part| part["ts"] == ts }
    return discard if parts.empty? || Journal.body_from(parts).blank?

    update(slack_parts: parts, slack_ts: parts.first["ts"], body: Journal.body_from(parts))
  end

  # Typed time in decimal hours ("1.5", "0.5"), never picked from presets. Every journal needs one.
  def duration=(text)
    @duration_text_given = text.to_s.strip
    self.duration_minutes = Duration.parse(@duration_text_given)
  end

  private

  def body_long_enough
    length = Journal.written_length(body)
    needed = Journal.body_length_needed(duration_minutes)
    return if body.blank? || length >= needed

    hours = needed > MIN_BODY_LENGTH ? " for #{duration_text}" : ""
    errors.add(:body, "needs at least #{needed} characters#{hours} so a reviewer can follow what you did (#{length} so far)")
  end

  # Older journals saved without a time can still be edited from Slack and deleted; any time typed must be real.
  def duration_was_understood
    return if duration_minutes.present? || @picked_timelapses.present? || (persisted? && @duration_text_given.nil?)

    errors.add(:duration, @duration_text_given.present? ? "should be in hours, like 1.5 or 0.5" : "is needed: how long did this take?")
  end

  # New journals and changed hours need the full count. An older journal may keep the photos it has, but not lose any.
  def images_cover_hours
    return if duration_minutes.nil?

    needed = images_needed
    needed = [ needed, images_attachments.size ].min if persisted? && !duration_minutes_changed?
    have = images.attachments.size + incoming_images.to_i
    errors.add(:images, "at least #{needed} for #{duration_text}, one per #{MINUTES_PER_IMAGE / 60} hours") if have < needed
  end

  def sync_xp = XpEntry.sync(self)

  # In one insert rather than one per photo (config/initializers/active_storage.rb).
  def analyze_images_later
    blobs = @attached_images.map(&:blob).reject(&:analyzed?)
    @attached_images = nil
    ActiveJob.perform_all_later(blobs.map { |blob| ActiveStorage::AnalyzeJob.new(blob) })
  end

  # Picked timelapses fill in the hours only when none were typed. Typed hours always stand; reviewers compare them
  # with the timelapses and the tracked time (hours_self_claimed).
  def take_hours_from_lapse
    return if duration_minutes.present? || @picked_timelapses.blank?

    self.duration_minutes = @picked_timelapses.sum(&:duration_minutes).nonzero?
  end

  # What the huddle and the site timer counted since the person's last journal, as it stood when this one was
  # written. The form offers it as the hours.
  def snapshot_tracked_time
    self.tracked_minutes = TrackedTime.new(user).seconds / 60 if user
  end

  # Hours over both the tracked time and the picked timelapses' recorded time are the person's own claim. Claiming
  # less is not. Unknown for journals from before tracking.
  def mark_self_claimed
    return self.hours_self_claimed = nil if duration_minutes.nil? || tracked_minutes.nil?

    lapse_minutes = (@picked_timelapses || lapse_timelapses).sum(&:duration_minutes)
    self.hours_self_claimed = duration_minutes > [ tracked_minutes, lapse_minutes ].max + CLAIM_LEEWAY
  end

  # Hours are fixed once logged, and so are the timelapses behind them: dropping one would free it for another
  # journal. A journal saved without hours can still be given them once.
  def hours_unchanged
    return if duration_minutes_in_database.nil?

    errors.add(:duration, "can't be changed once logged") if duration_minutes_changed?
    errors.add(:lapse_timelapses, "can't be changed once the hours are logged") if @picked_timelapses && @picked_timelapses.map(&:id).sort != lapse_timelapses.ids.sort
  end

  # Ones already on this journal stay even if Lapse has since changed them; newly picked ones must be watchable and free.
  def picked_timelapses_are_usable
    return errors.add(:lapse_timelapses, "at most #{MAX_TIMELAPSES} per journal") if @picked_timelapses.size > MAX_TIMELAPSES

    # Read again and held until this save commits, so two journals saved at once can't both take one timelapse.
    claimed = LapseTimelapse.where(id: @picked_timelapses.map(&:id)).order(:id).lock.pluck(:id, :journal_id).to_h
    added = @picked_timelapses.reject { |timelapse| persisted? && claimed[timelapse.id] == id }
    taken = Journal.kept.where(id: added.filter_map { |timelapse| claimed[timelapse.id] }).pluck(:id).to_set
    added.each do |timelapse|
      reason = if timelapse.user_id != user_id then "must be yours"
      elsif taken.include?(claimed[timelapse.id]) then "is already on another journal"
      else timelapse.unusable_reason
      end
      errors.add(:lapse_timelapses, "“#{timelapse.name.presence || 'Untitled timelapse'}” #{reason}") if reason
    end
  end

  def claim_picked_timelapses
    ids = @picked_timelapses.map(&:id)
    LapseTimelapse.where(journal_id: id).where.not(id: ids).each { |timelapse| timelapse.update!(journal_id: nil) }
    LapseTimelapse.where(id: ids).each { |timelapse| timelapse.update!(journal_id: id) }
    @picked_timelapses = nil
    lapse_timelapses.reset
  end

  def images_are_new_uploads
    added = images.attachments.select(&:new_record?).map(&:blob)
    errors.add(:images, "must be photos you uploaded for this journal") if Journal.reused_uploads?(added, uploaders: [ user_id ], record: self)
  end

  # The writing shows only this journal's own photos, never a picture from anywhere else.
  def embeds_only_own_photos
    sources = body.to_s.scan(EMBEDDED_IMAGE).flatten
    raw_image = body.to_s.match?(/<img\b|!\[[^\]]*\]\[/i)
    return if sources.empty? && !raw_image

    own = images.attachments.map(&:blob_id)
    foreign = raw_image || sources.any? do |source|
      id = source[PHOTO_PATH, 1]
      id.nil? || !ActiveStorage::Blob.find_signed(CGI.unescape(id))&.id.in?(own)
    end
    errors.add(:body, "can only show photos uploaded to this journal") if foreign
  end

  def images_are_images
    blobs = images.attachments.filter_map(&:blob)
    errors.add(:images, "at most #{MAX_IMAGES} per journal") if blobs.size > MAX_IMAGES
    errors.add(:images, "must be PNG, JPEG, GIF or WebP") unless blobs.all? { |blob| blob.content_type.in?(IMAGE_TYPES) }
    errors.add(:images, "must be under #{MAX_IMAGE_BYTES / 1.megabyte} MB each") if blobs.any? { |blob| blob.byte_size > MAX_IMAGE_BYTES }
  end

  def author_on_team
    return if project.nil? || project.on_team?(user)

    errors.add(:project, "must be one you're on the team of")
  end
end
