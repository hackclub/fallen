# Every minute: anyone whose tracked time (TrackedTime) is counting, in the huddle or on the site's timer, and has
# passed the next TimeMilestone gets a check-in in their DMs from their pet (SlackMessages.time_check_in), asking
# what they have got done so far, with a button to stop counting. The pet on the site asks the same.
class TimeMilestoneJob < ApplicationJob
  queue_as :slack
  limits_concurrency to: 1, key: "time_milestones", duration: 5.minutes

  def perform
    return unless SlackBot.configured?

    counting_users.find_each do |user|
      time = TrackedTime.new(user)
      next unless time.running.in?(%w[huddle timer])

      check_in = TimeMilestone.claim(time) or next
      ask(check_in, time.running)
    end
  end

  private

  def counting_users
    in_huddle = HuddleSession.ongoing.where("mode IS DISTINCT FROM 'chilling'").select(:user_id)
    on_timer = TimerSession.running.select(:user_id)
    User.kept.where.not(slack_id: nil).where(id: in_huddle).or(User.kept.where.not(slack_id: nil).where(id: on_timer))
  end

  def ask(check_in, running)
    posted = SlackBot.client.chat_postMessage(channel: check_in.user.slack_id, **SlackMessages.time_check_in(check_in, running))
    check_in.update_columns(dm_channel_id: posted["channel"], dm_ts: posted["ts"])
  rescue Slack::Web::Api::Errors::SlackError => e
    # The check-in stays claimed: a missed one is better than a repeated one. The pet on the site still asks.
    Rails.logger.warn({ event: "time_milestone.failed", user_id: check_in.user_id, minutes: check_in.minutes, error: e.message }.to_json)
  end
end
