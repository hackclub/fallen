# A check-in: every EVERY of tracked time (TrackedTime) someone gets asked in their Slack DMs, and on the pet, what
# they have got done so far (TimeMilestoneJob). The row is written before the message is sent and is unique per
# journal stretch, so no check-in is ever sent twice, whatever runs at once. `done` is their answer, from either
# place; `dm_channel_id` and `dm_ts` are the DM, so an answer on the site can show there too.
# == Schema Information
#
# Table name: time_milestones
#
#  id            :bigint           not null, primary key
#  answered_at   :datetime
#  dm_ts         :string
#  done          :text
#  minutes       :integer          not null
#  since         :datetime         not null
#  created_at    :datetime         not null
#  dm_channel_id :string
#  user_id       :bigint           not null
#
# Indexes
#
#  index_time_milestones_on_user_id_and_since_and_minutes  (user_id,since,minutes) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class TimeMilestone < ApplicationRecord
  include PublicIdentifiable
  set_public_id_prefix :tcm
  has_paper_trail

  EVERY = 1.hour
  # `since` for someone with no journal yet, since the unique index cannot tell NULLs apart.
  BEGINNING = Time.zone.at(0)

  belongs_to :user

  validates :done, length: { maximum: 1000 }

  after_commit -> { TimerChannel.changed(user_id) }, on: :update

  # The newest check-in in `time`, while something is counting and until it is answered. An older one left
  # unanswered is not asked again. Asks nothing before the first one could exist, so the pet's poll costs no query
  # for most of an hour.
  def self.pending(time)
    return unless time.running.in?(%w[huddle timer]) && time.seconds >= EVERY

    newest = where(user: time.user, since: time.since || BEGINNING).order(minutes: :desc).first
    newest unless newest&.answered?
  end

  # Claims the check-in `time` has reached, if it is past the last one sent. Returns it when this call claimed it,
  # nil otherwise. Only the newest is claimed, so a stretch found late gets one message, not a
  # backlog.
  def self.claim(time)
    minutes = (time.seconds / EVERY.to_i) * EVERY.in_minutes.to_i
    since = time.since || BEGINNING
    return if minutes.zero? || where(user: time.user, since: since, minutes: minutes..).exists?

    inserted = insert_all([ { user_id: time.user.id, since: since, minutes: minutes, created_at: Time.current } ],
      unique_by: %i[user_id since minutes], returning: %i[id])
    find(inserted.first["id"]).tap { |check_in| check_in.user = time.user } if inserted.any?
  end

  def answered? = answered_at.present?

  # Their answer. False, with an error on `done`, for an empty one.
  def answer!(done, at: Time.current)
    done = done.to_s.strip
    if done.blank?
      errors.add(:done, "can't be empty")
      return false
    end

    update!(done: done.truncate(1000), answered_at: at)
  end
end
