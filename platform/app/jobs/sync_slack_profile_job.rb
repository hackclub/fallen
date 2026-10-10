class SyncSlackProfileJob < ApplicationJob
  queue_as :background
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5
  discard_on Slack::Web::Api::Errors::UserNotFound

  def perform(user)
    return unless SlackBot.configured?

    user.sync_slack_profile!
  end
end
