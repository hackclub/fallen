# Slack ended the last huddle while these people were still in it. Mentions them in the new huddle's thread so
# they can hop over.
class HuddleHandoffJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(huddle, slack_ids)
    return if huddle.ended?

    SlackBot.client.chat_postMessage(channel: huddle.channel_id, thread_ts: huddle.thread_ts, **SlackMessages.huddle_handoff(huddle, slack_ids))
  end
end
