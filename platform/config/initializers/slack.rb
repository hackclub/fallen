# frozen_string_literal: true

Slack.configure do |config|
  config.token = ENV["SLACK_BOT_TOKEN"]
end

Slack::Events.configure do |config|
  config.signing_secret = ENV["SLACK_SIGNING_SECRET"]
  config.signature_expires_in = 5.minutes.to_i
end

# Changes made from Slack are attributed to the person who sent the payload and tagged with the handler.
Rails.application.config.to_prepare do
  SlackBot.around_handler = lambda do |handler, &run|
    PaperTrail.request(whodunnit: handler.user&.id, controller_info: { source: "slack:#{handler.class.name}" }, &run)
  end
end
