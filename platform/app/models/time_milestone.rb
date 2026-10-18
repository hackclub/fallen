# A milestone someone reached in the time since their last journal (TrackedTime), every EVERY of it, so they get
# one congratulations in Slack for it (TimeMilestoneJob). The row is written before the message is sent and is
# unique per journal stretch, so no milestone is ever announced twice, whatever runs at once.
# == Schema Information
#
# Table name: time_milestones
#
#  id         :bigint           not null, primary key
#  minutes    :integer          not null
#  since      :datetime         not null
#  created_at :datetime         not null
#  user_id    :bigint           not null
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
  has_paper_trail

  EVERY = 30.minutes
  # `since` for someone with no journal yet, since the unique index cannot tell NULLs apart.
  BEGINNING = Time.zone.at(0)

  belongs_to :user

  # Claims the milestone `time` has reached, if it is past the last one announced. Returns its minutes when this
  # call claimed it, nil otherwise. Only the newest is claimed, so a stretch found late gets one message, not a
  # backlog.
  def self.claim(time)
    minutes = (time.seconds / EVERY.to_i) * EVERY.in_minutes.to_i
    since = time.since || BEGINNING
    return if minutes.zero? || where(user: time.user, since: since, minutes: minutes..).exists?

    inserted = insert_all([ { user_id: time.user.id, since: since, minutes: minutes, created_at: Time.current } ],
      unique_by: %i[user_id since minutes], returning: %i[id])
    minutes if inserted.any?
  end
end
