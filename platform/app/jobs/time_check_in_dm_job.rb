# Someone answered their check-in on the pet (TimeCheckInsController): the DM (TimeMilestoneJob) shows the answer
# too, instead of still asking.
class TimeCheckInDmJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(check_in)
    return if check_in.dm_ts.nil?

    SlackBot.client.chat_update(channel: check_in.dm_channel_id, ts: check_in.dm_ts, **SlackMessages.time_check_in(check_in, TrackedTime.new(check_in.user).running))
  rescue Slack::Web::Api::Errors::SlackError => e
    raise if e.is_a?(Slack::Web::Api::Errors::TooManyRequestsError)

    Rails.logger.warn({ event: "time_check_in_dm.failed", check_in: check_in.public_id, error: e.message }.to_json)
  end
end
