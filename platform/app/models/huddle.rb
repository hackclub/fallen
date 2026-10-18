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
#  link          :string
#  message_count :integer          default(0), not null
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
  # Someone who was in the last huddle when it ended and joins this one this soon after it started keeps their answer.
  CARRY_OVER = 15.minutes
  # Leaving and coming back this fast is a dropped connection, not a new visit, so someone who had answered is not
  # asked again.
  REJOIN_QUIET = 30.seconds
  # Someone who has not answered is asked again after this many messages in the huddle's thread.
  REPROMPT_EVERY = 10

  has_many :sessions, class_name: "HuddleSession", dependent: :destroy

  validates :call_id, :channel_id, :started_at, presence: true

  scope :live, -> { where(ended_at: nil) }

  # The huddle running in SLACK_HUDDLE_CHANNEL_ID now, if one is set up.
  def self.current = SlackHuddle.channel_id && live.where(channel_id: SlackHuddle.channel_id).order(:started_at).last

  def ended? = ended_at.present?

  # Closes every open session at the moment the huddle ended, or earlier for anyone known to have left before.
  def end!(at)
    transaction do
      update!(ended_at: at)
      sessions.ongoing.find_each { |session| session.leave!(*departure(session, at, "huddle_end")) }
    end
  end

  # When someone Slack lists now arrived, and how that is known (HuddleSession::SOURCES): their join event after
  # `after` (their last visit ending, or the huddle starting), or now.
  def arrival(slack_id, after:, now:)
    joined = HuddleEvent.last_at(call_id, slack_id, "joined", since: after)
    joined ? [ [ joined, now ].min, "event" ] : [ now, "sync" ]
  end

  # When someone Slack no longer lists left, and how that is known: their leave event, the last sync that saw them
  # if syncs had stopped, or `now` as `source`.
  def departure(session, now, source = "sync")
    if (left = HuddleEvent.last_at(call_id, session.slack_id, "left", since: session.joined_at))
      [ [ left, now ].min, "event" ]
    elsif session.unseen_at?(now)
      [ session.last_seen_at, "unseen" ]
    else
      [ now, source ]
    end
  end

  # The Slack ids of people who were still in it when it ended.
  def present_at_end
    return [] unless ended?

    sessions.where(left_at: (ended_at - END_GRACE)..).distinct.pluck(:slack_id)
  end

  # The huddle that ended just before this one started, if there was one.
  def previous
    return @previous if defined?(@previous)

    @previous = Huddle.where(channel_id: channel_id, ended_at: (started_at - HANDOFF_WITHIN)..).where.not(id: id).order(ended_at: :desc).first
  end

  # The sessions, by Slack id, that these people had in the previous huddle when it ended, as long as they are
  # arriving within CARRY_OVER of this one starting.
  def carried_over(slack_ids, at:)
    return {} if slack_ids.empty? || at > started_at + CARRY_OVER || previous.nil?

    previous.sessions.where(slack_id: slack_ids, left_at: (previous.ended_at - END_GRACE)..).order(:joined_at).index_by(&:slack_id)
  end

  # A message in the huddle's thread. Returns the open sessions of people who still have not answered and have
  # had REPROMPT_EVERY messages go by since they were last asked, marked as asked now.
  def message_posted!
    Huddle.update_counters(id, message_count: 1)
    count = Huddle.where(id: id).pick(:message_count)
    due = sessions.ongoing.where(mode: nil).where(prompted_at_count: ..(count - REPROMPT_EVERY)).to_a
    HuddleSession.where(id: due.map(&:id)).update_all(prompted_at_count: count)
    due
  end

  # The message Slack posts for the huddle, which carries its Join button.
  def slack_url = thread_ts && SlackMessaging.permalink(channel_id, thread_ts)

  # Opens the huddle itself in Slack.
  def join_url = SlackHuddle.huddle_url(channel_id)
end
