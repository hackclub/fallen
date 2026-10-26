# Tells someone in a Slack DM that they earned the stupendous bonus (XpEntry.grant_stupendous), including the ones
# paid for older journals when it first went out.
class StupendousBonusJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(entry)
    return if entry.discarded? || entry.user.slack_id.blank? || !SlackBot.configured?

    SlackBot.client.chat_postMessage(channel: entry.user.slack_id, **SlackMessages.stupendous_bonus(entry.amount))
  end
end
