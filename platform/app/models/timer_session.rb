# Time counted on the site's own timer, started from the pet by someone who would rather not work in the huddle
# ("I'd prefer not"). Runs until they stop it. Adds to the time shown on the pet (TrackedTime) like a huddle
# session does.
# == Schema Information
#
# Table name: timer_sessions
#
#  id         :bigint           not null, primary key
#  started_at :datetime         not null
#  stopped_at :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_timer_sessions_on_user_id_and_started_at  (user_id,started_at)
#  index_timer_sessions_one_running_per_user       (user_id) UNIQUE WHERE (stopped_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class TimerSession < ApplicationRecord
  has_paper_trail

  # A timer left running counts no further than this; forgetting to stop it should not log a day.
  MAX_LENGTH = 8.hours

  belongs_to :user

  validates :started_at, presence: true

  scope :running, -> { where(stopped_at: nil) }

  after_commit -> { TimerChannel.changed(user_id) }

  # The time it counts up to: when it was stopped, or now, but never past MAX_LENGTH.
  def counted_until(now = Time.current) = [ stopped_at || now, started_at + MAX_LENGTH ].min

  # Starts someone's timer unless one is already counting. One that ran into MAX_LENGTH is closed there first.
  def self.start(user, at: Time.current)
    transaction do
      running = user.timer_sessions.running.lock.first
      return running if running && running.counted_until(at) == at

      running&.stop!(at)
      user.timer_sessions.create!(started_at: at)
    end
  end

  def stop!(at = Time.current) = update!(stopped_at: at.clamp(started_at, started_at + MAX_LENGTH))

  # Stops whatever timer they have running. Only touches one still running, so a second press or another tab
  # never moves a stop already written: the lock makes a racing stop wait, then find nothing left running.
  def self.stop(user, at: Time.current)
    stopped = transaction { running.where(user: user).lock.to_a.each { |session| session.stop!(at) } }
    TimerChannel.changed(user) if stopped.any?
  end
end
