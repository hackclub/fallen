class SlackAvatarJob < ApplicationJob
  queue_as :realtime
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 3

  def perform(email)
    SlackAvatars.look_up!(email)
  end
end
