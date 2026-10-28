# DMs someone what an admin changed on their streak (StreakAdjustment with `notify`), with the admin's message if they
# wrote one. Nothing for someone without Slack linked, or once the change is undone.
class StreakAdjustedJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(adjustment)
    user = adjustment.user
    return if adjustment.discarded? || user.nil? || user.slack_id.blank? || !SlackBot.configured?

    SlackBot.client.chat_postMessage(channel: user.slack_id, **SlackMessages.streak_adjusted(adjustment))
  end
end
