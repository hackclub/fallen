# frozen_string_literal: true

module SlackBot
  class Router
    attr_reader :kind, :payload

    def initialize(kind, payload)
      @kind = kind.to_sym
      @payload = payload
    end

    def call
      handler_class = resolve
      unless handler_class
        SlackBot.logger.info({ event: "slack_bot.unhandled", kind: kind, name: handler_name }.to_json)
        return nil
      end

      handler_class.new(payload).run
    rescue StandardError => e
      raise if Rails.env.local?

      Sentry.capture_exception(e, extra: { slack_kind: kind, slack_handler: handler_name })
      SlackBot.logger.error({ event: "slack_bot.error", kind: kind, name: handler_name, error: e.message }.to_json)
      error_response
    end

    # The conventional handler name for this payload, e.g. "ping" for /ping.
    def handler_name
      case kind
      when :command then payload.command.to_s.delete_prefix("/")
      when :event then payload.dig("event", "type")
      when :interaction
        case payload.type
        when "block_actions" then payload.actions&.first&.action_id.to_s.split(":").first
        when "view_submission", "view_closed" then payload.dig("view", "callback_id")
        when "shortcut", "message_action" then payload.callback_id
        end
      end
    end

    def handler_suffix
      case kind
      when :command then "Command"
      when :event then "Event"
      when :interaction
        case payload.type
        when "block_actions" then "Action"
        when "view_submission", "view_closed" then "View"
        when "shortcut", "message_action" then "Shortcut"
        end
      end
    end

    def resolve
      name = handler_name.presence or return nil
      suffix = handler_suffix or return nil

      klass = "#{name.to_s.tr('-', '_').camelize}#{suffix}".safe_constantize
      klass if klass.is_a?(Class) && klass < SlackBot::Handler
    end

    private

    def error_response
      return nil if kind == :event

      { response_type: "ephemeral", text: ":warning: Something went wrong on our end. Please try again." }
    end
  end
end
