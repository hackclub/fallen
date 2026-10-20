class SlackJoinJob < ApplicationJob
  queue_as :slack
  # Slack retries and double clicks: one at a time per Slack ID, so the second finds the first's account.
  limits_concurrency key: ->(slack_id, *) { slack_id }, duration: 1.minute
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5
  discard_on Slack::Web::Api::Errors::UserNotFound

  def perform(slack_id, signup_source = {})
    return unless SlackAvatars.configured?

    User.join_from_slack!(slack_id, signup_source: signup_source)
  end
end
