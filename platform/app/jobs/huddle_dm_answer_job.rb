# Someone answered the huddle prompt in the thread: the copy in their DMs (HuddlePromptJob) shows the answer too,
# instead of still asking.
class HuddleDmAnswerJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(session)
    return if session.prompt_dm_ts.nil?

    SlackBot.client.chat_update(channel: session.dm_channel_id, ts: session.prompt_dm_ts, **SlackMessages.huddle_answer(session))
  rescue Slack::Web::Api::Errors::SlackError => e
    raise if e.is_a?(Slack::Web::Api::Errors::TooManyRequestsError)

    Rails.logger.warn({ event: "huddle_dm_answer.failed", session: session.public_id, error: e.message }.to_json)
  end
end
