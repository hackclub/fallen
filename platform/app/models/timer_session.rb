# Time counted on the site's own timer, started from the pet by someone who would rather not work in the huddle
# ("I'd prefer not"), with what they mean to work on (`goal`). Runs until they stop it or it reaches MAX_LENGTH.
# Adds to the time shown on the pet (TrackedTime) like a huddle session does. Once it stops they are asked what
# they got done and how much of it was really work (`wrap_up!`).
# == Schema Information
#
# Table name: timer_sessions
#
#  id               :bigint           not null, primary key
#  deducted_seconds :integer          default(0), not null
#  done             :text
#  goal             :text
#  started_at       :datetime         not null
#  stopped_at       :datetime
#  wrapped_up_at    :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_timer_sessions_on_stopped_at              (stopped_at)
#  index_timer_sessions_on_user_id_and_started_at  (user_id,started_at)
#  index_timer_sessions_one_running_per_user       (user_id) UNIQUE WHERE (stopped_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class TimerSession < ApplicationRecord
  has_paper_trail

  # A timer left running counts no further than this; forgetting to stop it should not log a day. The pet says so
  # before it starts.
  MAX_LENGTH = 6.hours
  # A start and stop closer than this is a misclick, not worth asking about.
  WRAP_UP_MIN = 1.minute

  belongs_to :user

  validates :started_at, presence: true
  validates :goal, length: { maximum: 500 }

  scope :running, -> { where(stopped_at: nil) }

  after_commit -> { TimerChannel.changed(user_id) }

  # The time it counts up to: when it was stopped, or now, but never past MAX_LENGTH.
  def counted_until(now = Time.current) = [ stopped_at || now, started_at + MAX_LENGTH ].min

  def counted_seconds(now = Time.current) = (counted_until(now) - started_at).to_i

  # Starts someone's timer unless one is already counting. One that ran into MAX_LENGTH is closed there first.
  def self.start(user, goal: nil, at: Time.current)
    transaction do
      running = user.timer_sessions.running.lock.first
      return running if running && running.counted_until(at) == at

      running&.stop!(at)
      user.timer_sessions.create!(started_at: at, goal: goal&.squish&.truncate(500))
    end
  end

  # What they got done, and how many of the counted hours were really work (HonestHours).
  # Stops it if it ran into MAX_LENGTH without being stopped. False, with an error on `hours`, for more hours than
  # it counted.
  def wrap_up!(done:, hours:, at: Time.current)
    counted = counted_seconds(at)
    deducted = HonestHours.deduction(hours, counted)
    if deducted.nil?
      errors.add(:hours, "can be at most #{HonestHours.text(counted)}")
      return false
    end

    update!(done: done.to_s.strip.presence&.truncate(1000), deducted_seconds: deducted, wrapped_up_at: at, stopped_at: stopped_at || counted_until(at))
  end

  def stop!(at = Time.current) = update!(stopped_at: at.clamp(started_at, started_at + MAX_LENGTH))

  # Stops whatever timer they have running. Only touches one still running, so a second press or another tab
  # never moves a stop already written: the lock makes a racing stop wait, then find nothing left running.
  def self.stop(user, at: Time.current)
    stopped = transaction { running.where(user: user).lock.to_a.each { |session| session.stop!(at) } }
    TimerChannel.changed(user) if stopped.any?
  end
end
