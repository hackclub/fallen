# frozen_string_literal: true

require "yaml"

module SlackBot
  # Builds a Slack app manifest from the handlers in app/bot. `bin/slack-manifest` prints it;
  # paste it at https://api.slack.com/apps -> Create New App -> From a manifest.
  module Manifest
    # Kept to what the handlers use: Enterprise Grid refuses installs that ask for more than it allows.
    BOT_SCOPES = %w[
      app_mentions:read
      channels:history
      chat:write
      chat:write.customize
      commands
      files:read
      groups:history
      reactions:write
      users:read
    ].freeze

    module_function

    def generate(app_url:, name: "Fallen", socket_mode: false)
      Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/bot")) if Rails.root.join("app/bot").exist?

      {
        "display_information" => { "name" => name },
        "features" => {
          "bot_user" => { "display_name" => name, "always_online" => true },
          "slash_commands" => commands.map { |klass|
            {
              "command" => klass.command_name,
              "url" => (socket_mode ? nil : "#{app_url}/slack/commands"),
              "description" => klass.description,
              "usage_hint" => klass.usage_hint,
              "should_escape" => klass.should_escape
            }.compact
          }
        },
        "oauth_config" => {
          # Slack only accepts https redirect URLs, so a plain-http dev APP_URL leaves "Connect Slack" unconfigured.
          "redirect_urls" => (app_url.start_with?("https://") ? [ "#{app_url}/auth/slack/callback" ] : nil),
          "scopes" => { "bot" => BOT_SCOPES, "user" => SlackMessaging::USER_SCOPES }
        }.compact,
        "settings" => {
          "event_subscriptions" => {
            "request_url" => (socket_mode ? nil : "#{app_url}/slack/events"),
            "bot_events" => events.flat_map(&:subscribes_to).uniq.sort
          }.compact,
          "interactivity" => {
            "is_enabled" => true,
            "request_url" => (socket_mode ? nil : "#{app_url}/slack/interactions")
          }.compact,
          "org_deploy_enabled" => false,
          "socket_mode_enabled" => socket_mode,
          "token_rotation_enabled" => false
        }
      }
    end

    def to_yaml(**options) = generate(**options).to_yaml
    def to_json(**options) = JSON.pretty_generate(generate(**options))

    def commands = SlackBot::Command.descendants.sort_by(&:name)
    def events = SlackBot::Event.descendants.sort_by(&:name)
  end
end
