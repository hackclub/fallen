# One run of the huddle the user bot keeps open in SLACK_HUDDLE_CHANNEL_ID (script/slack_huddle.mjs). Slack ends
# every huddle after 24 hours and the bot starts the next one, so there is a row per run. HuddleSyncJob keeps the
# rows and their HuddleSessions in step with Slack.
# == Schema Information
#
# Table name: huddles
#
#  id            :bigint           not null, primary key
#  ended_at      :datetime
#  handed_off_at :datetime
#  started_at    :datetime         not null
#  thread_ts     :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  call_id       :string           not null
#  channel_id    :string           not null
#
# Indexes
#
#  index_huddles_on_call_id   (call_id) UNIQUE
#  index_huddles_on_ended_at  (ended_at)
#
class Huddle < ApplicationRecord
  # Slack drops everyone when it ends a huddle, and their leave events can land just before the end does. Anyone who
  # left this close to the end was still there when it ended.
  END_GRACE = 1.minute
  # Past this, a restart is no longer worth pinging anyone about.
  HANDOFF_WITHIN = 1.hour

  has_many :sessions, class_name: "HuddleSession", dependent: :destroy

  validates :call_id, :channel_id, :started_at, presence: true

  scope :live, -> { where(ended_at: nil) }

  def ended? = ended_at.present?

  # Closes every open session at the moment the huddle ended.
  def end!(at)
    transaction do
      update!(ended_at: at)
      sessions.ongoing.find_each { |session| session.leave!(at) }
    end
  end

  # The Slack ids of people who were still in it when it ended.
  def present_at_end
    return [] unless ended?

    sessions.where(left_at: (ended_at - END_GRACE)..).distinct.pluck(:slack_id)
  end

  # The ended huddle whose people should be asked to join this one, if it has not been done yet.
  def previous_for_handoff
    Huddle.where(channel_id: channel_id, handed_off_at: nil, ended_at: (started_at - HANDOFF_WITHIN)..).where.not(id: id).order(ended_at: :desc).first
  end

  # The message Slack posts for the huddle, which carries its Join button.
  def slack_url = thread_ts && SlackMessaging.permalink(channel_id, thread_ts)
end
