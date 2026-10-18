# Asks someone who just joined the huddle what they are working on, privately in the huddle's thread and as their
# pet when they have one. HuddleGoalAction takes the answer.
class HuddlePromptJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(session)
    return if session.left_at

    huddle = session.huddle
    SlackBot.client.chat_postEphemeral(channel: huddle.channel_id, user: session.slack_id, thread_ts: huddle.thread_ts, **SlackMessages.huddle_prompt(session))
  rescue Slack::Web::Api::Errors::SlackError => e
    raise if e.is_a?(Slack::Web::Api::Errors::TooManyRequestsError)

    Rails.logger.warn({ event: "huddle_prompt.failed", session: session.public_id, error: e.message }.to_json)
  end
end
