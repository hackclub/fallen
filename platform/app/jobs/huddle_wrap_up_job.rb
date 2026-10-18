# Someone left the huddle (HuddleSession#leave!) a little while ago. Their pet DMs them asking what they got done,
# when HuddleSession#wrap_up_due? says it is worth asking; HuddleDoneAction takes the answer.
class HuddleWrapUpJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(session)
    return unless session.wrap_up_due?

    SlackBot.client.chat_postMessage(channel: session.slack_id, unfurl_links: false, **SlackMessages.huddle_wrap_up(session))
    session.update!(wrap_up_asked_at: Time.current)
  rescue Slack::Web::Api::Errors::SlackError => e
    raise if e.is_a?(Slack::Web::Api::Errors::TooManyRequestsError)

    Rails.logger.warn({ event: "huddle_wrap_up.failed", session: session.public_id, error: e.message }.to_json)
  end
end
