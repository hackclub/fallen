# frozen_string_literal: true

require "yaml"

module SlackBot
  # Builds a Slack app manifest from the handlers in app/bot. `bin/slack-manifest` prints it;
  # paste it at https://api.slack.com/apps -> Create New App -> From a manifest.
  module Manifest
    BOT_SCOPES = %w[
      app_mentions:read
      channels:history
      chat:write
      chat:write.public
      commands
      groups:history
      im:history
      im:write
      reactions:write
      users:read
      users:read.email
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
              "url" => "#{app_url}/slack/commands",
              "description" => klass.description,
              "usage_hint" => klass.usage_hint,
              "should_escape" => klass.should_escape
            }.compact
          }
        },
        "oauth_config" => { "scopes" => { "bot" => BOT_SCOPES } },
        "settings" => {
          "event_subscriptions" => {
            "request_url" => "#{app_url}/slack/events",
            "bot_events" => events.map(&:event_type).sort
          },
          "interactivity" => {
            "is_enabled" => true,
            "request_url" => "#{app_url}/slack/interactions"
          },
          "org_deploy_enabled" => false,
          "socket_mode_enabled" => socket_mode,
          "token_rotation_enabled" => false
        }
      }
    end

    def to_yaml(**options) = generate(**options).to_yaml

    def commands = SlackBot::Command.descendants.sort_by(&:name)
    def events = SlackBot::Event.descendants.sort_by(&:name)
  end
end
