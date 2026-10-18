# One session of work on a Project. Lives twice: here, and as a reply in the project's Slack thread.
# `slack_ts` is the reply's timestamp, whichever side it was written on. `source` says where it was written.
# A journal written in Slack can span several replies (JournalDraft); `slack_parts` keeps each one's ts and
# text, so editing or deleting any of them in Slack updates the body.
# == Schema Information
#
# Table name: journals
#
#  id                 :bigint           not null, primary key
#  body               :text             not null
#  discarded_at       :datetime
#  duration_minutes   :integer
#  hours_self_claimed :boolean
#  lapse_url          :string
#  slack_parts        :jsonb            not null
#  slack_ts           :string
#  source             :string           default("web"), not null
#  tracked_minutes    :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  project_id         :bigint           not null
#  slack_channel_id   :string
#  user_id            :bigint           not null
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

  SOURCES = %w[web slack].freeze
  MAX_MINUTES = 24 * 60
  # Every two hours logged need a photo to show for them.
  MINUTES_PER_IMAGE = 120
  MAX_TIMELAPSES = 10
  # A journal needs this much writing for a reviewer to follow what was done. Photos embedded in it don't count.
  MIN_BODY_LENGTH = 100
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
  has_one :xp_entry, as: :source
  has_many_attached :images

  # Photos still being copied over from Slack (CollectSlackJournalJob), counted before they arrive.
  attr_accessor :incoming_images

  IMAGE_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  MAX_IMAGES = 10
  MAX_IMAGE_BYTES = 10.megabytes

  validates :body, presence: true, length: { maximum: 10_000 }
  # New journals, and edits on the site. Edits made in Slack always go through, so the journal keeps up with the
  # thread.
  validate :body_long_enough, if: -> { new_record? || (will_save_change_to_body? && from_web?) }
  validates :source, inclusion: { in: SOURCES }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_MINUTES }, allow_nil: true
  validates :slack_ts, uniqueness: { scope: :slack_channel_id }, allow_nil: true
  # Only on journals from before timelapses were picked from Lapse; nothing sets it any more, since a typed link
  # could point anywhere.
  validates :lapse_url, format: { with: %r{\Ahttps://\S+\z}, message: "must be a link starting with https://" }, allow_blank: true
  validate :author_owns_project
  validate :images_are_images
  validate :images_cover_hours, if: -> { new_record? || duration_minutes_changed? || attachment_changes.key?("images") }
  validate :duration_was_understood
  validate :picked_timelapses_are_usable, if: -> { @picked_timelapses }

  before_validation :take_hours_from_lapse
  before_validation :snapshot_tracked_time, on: :create
  before_save :mark_self_claimed, if: -> { new_record? || duration_minutes_changed? || @picked_timelapses }

  after_save :claim_picked_timelapses, if: -> { @picked_timelapses }
  after_save :sync_xp, if: -> { saved_change_to_duration_minutes? || saved_change_to_discarded_at? }
  # A new journal starts the pet's timer from zero; deleting the newest one brings its time back.
  after_commit -> { TimerChannel.changed(user_id) }, if: -> { previous_changes.key?("id") || previous_changes.key?("discarded_at") }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :needing_hours, -> { where(duration_minutes: nil) }

  def self.find_by_slack_message(channel_id, ts)
    return nil if channel_id.blank? || ts.blank?

    where(slack_channel_id: channel_id).where("slack_ts = :ts OR slack_parts @> CAST(:part AS jsonb)", ts: ts, part: [ { ts: ts } ].to_json).first
  end

  def self.body_from(parts) = parts.map { |part| part["text"] }.compact_blank.join("\n\n")

  def from_slack? = source == "slack"
  def from_web? = source == "web"
  def on_slack? = slack_channel_id.present? && slack_ts.present?
  def slack_url = on_slack? ? SlackMessaging.permalink(slack_channel_id, slack_ts, thread_ts: project.slack_thread_ts) : nil
  def hours_logged? = duration_minutes.present?
  def xp = xp_entry&.kept? ? xp_entry.amount : nil
  def images_needed = (duration_minutes.to_f / MINUTES_PER_IMAGE).ceil
  def duration_text = Duration.format(duration_minutes)

  # How much writing there is, leaving out embedded photos (Markdown images).
  def self.written_length(text) = text.to_s.gsub(/!\[[^\]]*\]\([^)]*\)/, "").strip.length
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
    return if body.blank? || length >= MIN_BODY_LENGTH

    errors.add(:body, "needs at least #{MIN_BODY_LENGTH} characters so a reviewer can follow what you did (#{length} so far)")
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

  # Ones already on this journal stay even if Lapse has since changed them; newly picked ones must be watchable and free.
  def picked_timelapses_are_usable
    return errors.add(:lapse_timelapses, "at most #{MAX_TIMELAPSES} per journal") if @picked_timelapses.size > MAX_TIMELAPSES

    added = @picked_timelapses.reject { |timelapse| persisted? && timelapse.journal_id == id }
    taken = Journal.kept.where(id: added.filter_map(&:journal_id)).pluck(:id).to_set
    added.each do |timelapse|
      reason = if timelapse.user_id != user_id then "must be yours"
      elsif taken.include?(timelapse.journal_id) then "is already on another journal"
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

  def images_are_images
    blobs = images.attachments.filter_map(&:blob)
    errors.add(:images, "at most #{MAX_IMAGES} per journal") if blobs.size > MAX_IMAGES
    errors.add(:images, "must be PNG, JPEG, GIF or WebP") unless blobs.all? { |blob| blob.content_type.in?(IMAGE_TYPES) }
    errors.add(:images, "must be under #{MAX_IMAGE_BYTES / 1.megabyte} MB each") if blobs.any? { |blob| blob.byte_size > MAX_IMAGE_BYTES }
  end

  def author_owns_project
    return if project.nil? || project.user_id == user_id

    errors.add(:project, "must be yours")
  end
end
