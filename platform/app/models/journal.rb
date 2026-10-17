# One session of work on a Project. Lives twice: here, and as a reply in the project's Slack thread.
# `slack_ts` is the reply's timestamp, whichever side it was written on. `source` says where it was written.
# A journal written in Slack can span several replies (JournalDraft); `slack_parts` keeps each one's ts and
# text, so editing or deleting any of them in Slack updates the body.
# == Schema Information
#
# Table name: journals
#
#  id               :bigint           not null, primary key
#  body             :text             not null
#  discarded_at     :datetime
#  duration_minutes :integer
#  lapse_url        :string
#  slack_parts      :jsonb            not null
#  slack_ts         :string
#  source           :string           default("web"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  project_id       :bigint           not null
#  slack_channel_id :string
#  user_id          :bigint           not null
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

  set_public_id_prefix :jrn
  has_paper_trail

  belongs_to :project
  belongs_to :user
  has_one :xp_entry, as: :source
  has_many_attached :images

  # Photos still being copied over from Slack (CollectSlackJournalJob), counted before they arrive.
  attr_accessor :incoming_images

  IMAGE_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  MAX_IMAGES = 10
  MAX_IMAGE_BYTES = 10.megabytes

  validates :body, presence: true, length: { maximum: 10_000 }
  validates :source, inclusion: { in: SOURCES }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_MINUTES }, allow_nil: true
  validates :slack_ts, uniqueness: { scope: :slack_channel_id }, allow_nil: true
  validates :lapse_url, format: { with: %r{\Ahttps://\S+\z}, message: "must be a link starting with https://" }, allow_blank: true
  validate :author_owns_project
  validate :images_are_images
  validate :images_cover_hours, if: -> { new_record? || duration_minutes_changed? || attachment_changes.key?("images") }
  validate :duration_was_understood

  after_save :sync_xp, if: -> { saved_change_to_duration_minutes? || saved_change_to_discarded_at? }

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
  def multi_part? = slack_parts.size > 1

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

  # Typed time ("1.5", "1h 30m", "45m"), never picked from presets. Every journal needs one.
  def duration=(text)
    @duration_text_given = text.to_s.strip
    self.duration_minutes = Duration.parse(@duration_text_given)
  end

  private

  # Older journals saved without a time can still be edited from Slack and deleted; any time typed must be real.
  def duration_was_understood
    return if duration_minutes.present? || (persisted? && @duration_text_given.nil?)

    errors.add(:duration, @duration_text_given.present? ? "should look like 1h 30m, 2.5 or 45m" : "is needed: how long did this take?")
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
