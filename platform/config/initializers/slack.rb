# frozen_string_literal: true

Slack.configure do |config|
  config.token = ENV["SLACK_BOT_TOKEN"]
end

Slack::Events.configure do |config|
  config.signing_secret = ENV["SLACK_SIGNING_SECRET"]
  config.signature_expires_in = 5.minutes.to_i
end
