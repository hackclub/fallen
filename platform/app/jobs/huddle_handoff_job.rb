# Slack ended the last huddle while these people were still in it. Mentions them in the new huddle's thread and
# rings each of them into it so they can hop over. The rings are their own jobs, so a run cut short and started
# again (a deploy) never rings anyone twice, and a failed ring is never retried.
class HuddleHandoffJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(huddle, slack_ids)
    return if huddle.ended?

    SlackBot.client.chat_postMessage(channel: huddle.channel_id, thread_ts: huddle.thread_ts, **SlackMessages.huddle_handoff(huddle, slack_ids))
    ActiveJob.perform_all_later(slack_ids.map { |slack_id| HuddleRingJob.new(slack_id) }) if SlackHuddle.configured?
  end
end
