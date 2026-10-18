# Asks someone who just joined the huddle what they are working on, privately in the huddle's thread and as their
# pet when they have one. On joining (`dm`) the same question goes to their DMs, where it stays after they leave;
# HuddleGoalAction takes the answer from either and keeps the DM in step.
class HuddlePromptJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(session, dm: false)
    return if session.left_at

    huddle = session.huddle
    prompt = SlackMessages.huddle_prompt(session)
    post(session) { SlackBot.client.chat_postEphemeral(channel: huddle.channel_id, user: session.slack_id, thread_ts: huddle.thread_ts, **prompt) }
    return unless dm && session.prompt_dm_ts.nil?

    post(session) do
      message = SlackBot.client.chat_postMessage(channel: session.slack_id, unfurl_links: false, **prompt)
      session.update!(dm_channel_id: message.channel, prompt_dm_ts: message.ts)
    end
  end

  private

  def post(session)
    yield
  rescue Slack::Web::Api::Errors::SlackError => e
    raise if e.is_a?(Slack::Web::Api::Errors::TooManyRequestsError)

    Rails.logger.warn({ event: "huddle_prompt.failed", session: session.public_id, error: e.message }.to_json)
  end
end
