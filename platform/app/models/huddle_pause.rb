# Someone sitting in the huddle who pressed Pause on the pet and chose to stay: from `started_at` to `ended_at`
# their huddle time does not count (TrackedTime takes these out). Kept apart from HuddleSession so pausing never
# rewrites when anyone joined or left. Ends when they press Resume or leave the huddle (`end_reason`); a dropped
# connection that comes straight back stays paused (HuddleSyncJob).
# == Schema Information
#
# Table name: huddle_pauses
#
#  id         :bigint           not null, primary key
#  end_reason :string
#  ended_at   :datetime
#  started_at :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_huddle_pauses_on_user_id_and_started_at  (user_id,started_at)
#  index_huddle_pauses_one_open_per_user          (user_id) UNIQUE WHERE (ended_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class HuddlePause < ApplicationRecord
  has_paper_trail

  END_REASONS = %w[resumed left].freeze

  belongs_to :user

  validates :started_at, presence: true
  validates :end_reason, inclusion: { in: END_REASONS }, allow_nil: true

  scope :open, -> { where(ended_at: nil) }

  after_commit -> { TimerChannel.changed(user_id) }

  # Pauses someone who is in the huddle. Pausing again while paused changes nothing. Returns the open pause, or
  # nil when they are not in the huddle.
  def self.start(user, at: Time.current)
    return unless HuddleSession.ongoing.exists?(user: user)

    open.find_by(user: user) || create!(user: user, started_at: at)
  rescue ActiveRecord::RecordNotUnique
    open.find_by(user: user)
  end

  # Ends their open pause, if any. Only ever closes a pause that is still open, so a resume and a leave racing
  # each other cannot move an end already written. One that began after `at` ends where it began.
  def self.finish(user_ids, at:, reason:)
    ended = transaction do
      open.where(user_id: user_ids).lock.to_a.each { |pause| pause.update!(ended_at: [ pause.started_at, at ].max, end_reason: reason) }
    end
    ended.map(&:user_id).uniq.each { |user_id| TimerChannel.changed(user_id) }
  end
end
