# A timelapse the person recorded on Lapse, copied here by SyncLapseTimelapsesJob so the journal composer can list
# them without waiting on Lapse. Picking one for a journal makes its recorded time the journal's hours.
# == Schema Information
#
# Table name: lapse_timelapses
#
#  id               :bigint           not null, primary key
#  duration_seconds :integer          default(0), not null
#  name             :string
#  playback_url     :string
#  recorded_at      :datetime
#  thumbnail_url    :string
#  visibility       :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  journal_id       :bigint
#  lapse_id         :string           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_lapse_timelapses_on_journal_id   (journal_id)
#  index_lapse_timelapses_on_lapse_id     (lapse_id) UNIQUE
#  index_lapse_timelapses_on_recorded_at  (recorded_at)
#  index_lapse_timelapses_on_user_id      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (journal_id => journals.id)
#  fk_rails_...  (user_id => users.id)
#
class LapseTimelapse < ApplicationRecord
  include PublicIdentifiable

  # Lapse also lists timelapses that are private, still rendering or failed; only ones a reviewer can watch count.
  WATCHABLE_VISIBILITIES = %w[PUBLIC UNLISTED].freeze
  LISTED = 50

  set_public_id_prefix :lps

  belongs_to :user
  belongs_to :journal, optional: true

  validates :lapse_id, presence: true, uniqueness: true

  scope :newest_first, -> { order(recorded_at: :desc, id: :desc) }
  # Free to pick: on no journal, or on one that was deleted.
  scope :unclaimed, -> { where(journal_id: nil).or(where(journal_id: Journal.discarded.select(:id))) }

  # Replaces the person's copies with what Lapse has now. A timelapse already claimed by another Fallen account
  # stays theirs; one gone from Lapse is dropped unless a journal points at it.
  def self.sync(user)
    rows = Lapse.timelapses(user.lapse_token).map { |data| attributes_from(data).merge(user_id: user.id) }
    upsert_all(rows, unique_by: :lapse_id, update_only: %i[name duration_seconds visibility playback_url thumbnail_url recorded_at]) if rows.any?
    user.lapse_timelapses.where.not(lapse_id: rows.pluck(:lapse_id)).where(journal_id: nil).delete_all
    user.update!(lapse_synced_at: Time.current)
  rescue Lapse::Unauthorized
    user.disconnect_lapse!
  end

  def self.attributes_from(data)
    {
      lapse_id: data.fetch("id"),
      name: data["name"],
      duration_seconds: data["duration"].to_i,
      visibility: data["visibility"],
      playback_url: data["playbackUrl"],
      thumbnail_url: data["thumbnailUrl"],
      recorded_at: data["createdAt"] && Time.zone.at(data["createdAt"] / 1000.0)
    }
  end

  def duration_minutes = (duration_seconds / 60.0).round
  def duration_text = Duration.format(duration_minutes)
  def url = Lapse.timelapse_url(lapse_id)
  def usable? = unusable_reason.nil?

  # Why it can't back a journal, or nil when it can.
  def unusable_reason
    return "failed to render on Lapse" if visibility == "FAILED_PROCESSING"
    return "is still rendering on Lapse" if playback_url.blank?
    return "is private on Lapse; make it unlisted so staff can watch it" unless visibility.in?(WATCHABLE_VISIBILITIES)

    "is under a minute long" unless duration_minutes.positive?
  end
end
