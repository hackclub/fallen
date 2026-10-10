# frozen_string_literal: true

module SlackBot
  # Slash command. The file name decides the command: app/bot/ping_command.rb handles /ping.
  #
  #   class PingCommand < SlackBot::Command
  #     description "Check that the bot is alive"
  #     usage_hint "[anything]"
  #
  #     def call
  #       respond "pong (#{text})"
  #     end
  #   end
  class Command < Handler
    class << self
      def command_name = "/#{name.delete_suffix('Command').underscore.tr('_', '-')}"

      def description(value = nil)
        @description = value if value
        @description || "#{command_name} command"
      end

      def usage_hint(value = nil)
        @usage_hint = value if value
        @usage_hint
      end

      def should_escape(value = nil)
        @should_escape = value unless value.nil?
        @should_escape || false
      end
    end

    def text = payload.text.to_s.strip
    def args = text.split
    def command = payload.command

    private

    def inline_response_allowed? = true
  end
end
