# The main huddle just filled up (Huddle#full!). Says so in its thread, with where each team can huddle instead.
class HuddleFullJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(huddle)
    return if huddle.ended? || huddle.thread_ts.nil? || SlackHuddle.team_channel_ids.empty?

    SlackBot.client.chat_postMessage(channel: huddle.channel_id, thread_ts: huddle.thread_ts, **SlackMessages.huddle_full)
  end
end
