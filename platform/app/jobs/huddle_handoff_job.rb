# Slack ended the last huddle while these people were still in it. Mentions them in the new huddle's thread and
# rings each of them into it so they can hop over. A failed ring is logged, never retried, so a retry never posts
# twice.
class HuddleHandoffJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(huddle, slack_ids)
    return if huddle.ended?

    SlackBot.client.chat_postMessage(channel: huddle.channel_id, thread_ts: huddle.thread_ts, **SlackMessages.huddle_handoff(huddle, slack_ids))
    slack_ids.each { |slack_id| ring(slack_id) } if SlackHuddle.configured?
  end

  private

  def ring(slack_id)
    SlackHuddle.ring(slack_id)
  rescue SlackBot::BrowserClient::Error, Faraday::Error => e
    Rails.logger.warn({ event: "huddle_handoff.ring_failed", slack_id: slack_id, error: e.message }.to_json)
  end
end
