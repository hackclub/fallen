# Every minute: anyone whose time since their last journal (TrackedTime) is counting and has passed the next
# TimeMilestone gets a message only they can see, from their pet. In the huddle it goes in the huddle's thread;
# on the site's timer, to their DMs.
class TimeMilestoneJob < ApplicationJob
  queue_as :slack
  limits_concurrency to: 1, key: "time_milestones", duration: 5.minutes

  def perform
    return unless SlackBot.configured?

    counting_users.find_each do |user|
      time = TrackedTime.new(user)
      next unless time.running.in?(%w[huddle timer])

      minutes = TimeMilestone.claim(time) or next
      congratulate(user, minutes, in_huddle: time.running == "huddle")
    end
  end

  private

  def counting_users
    in_huddle = HuddleSession.ongoing.where("mode IS DISTINCT FROM 'chilling'").select(:user_id)
    on_timer = TimerSession.running.select(:user_id)
    User.kept.where.not(slack_id: nil).where(id: in_huddle).or(User.kept.where.not(slack_id: nil).where(id: on_timer))
  end

  def congratulate(user, minutes, in_huddle:)
    message = SlackMessages.time_milestone(user, minutes)
    huddle = Huddle.current if in_huddle
    begin
      return SlackBot.client.chat_postEphemeral(channel: huddle.channel_id, user: user.slack_id, thread_ts: huddle.thread_ts, **message) if huddle
    rescue Slack::Web::Api::Errors::SlackError
      # Not a member of the huddle's channel, most likely; their DMs always work.
    end
    SlackBot.client.chat_postMessage(channel: user.slack_id, **message)
  rescue Slack::Web::Api::Errors::SlackError => e
    # The milestone stays claimed: a missed congratulations is better than a repeated one.
    Rails.logger.warn({ event: "time_milestone.failed", user_id: user.id, minutes: minutes, error: e.message }.to_json)
  end
end
