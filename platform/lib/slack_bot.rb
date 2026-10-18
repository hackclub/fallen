# frozen_string_literal: true

# Tiny Slack app framework on top of slack-ruby-client.
#
# Slack hits SlackController (/slack/events, /slack/commands, /slack/interactions). Every payload is
# wrapped in SlackBot::Payload and routed by naming convention to a class in app/bot:
#
#   /ping                          -> PingCommand       < SlackBot::Command
#   event "app_mention"            -> AppMentionEvent   < SlackBot::Event
#   block action_id "say_hello"    -> SayHelloAction    < SlackBot::Action   ("say_hello:anything" works too)
#   view callback_id "feedback"    -> FeedbackView      < SlackBot::View
#   shortcut callback_id "report"  -> ReportShortcut    < SlackBot::Shortcut
#
# Handlers implement #call and get helpers like say, respond, open_modal, user (the matching User record).
# Locally, run the Socket Mode bridge (bin/dev starts it when SLACK_APP_TOKEN is set) so no tunnel is needed.
module SlackBot
  class << self
    def client
      @client ||= Slack::Web::Client.new(token: ENV.fetch("SLACK_BOT_TOKEN"))
    end

    def reset_client! = @client = nil

    def configured? = ENV["SLACK_BOT_TOKEN"].present? && ENV["SLACK_SIGNING_SECRET"].present?

    def logger = Rails.logger

    # Wraps every handler run, e.g. to tag what it changes: `SlackBot.around_handler = ->(handler, &run) { run.call }`.
    attr_writer :around_handler

    def around_handler = @around_handler ||= ->(_handler, &run) { run.call }

    # kind: :command, :event or :interaction. Returns the inline HTTP response body (Hash) or nil.
    def handle(kind, raw_payload)
      Router.new(kind, Payload.wrap(raw_payload)).call
    end
  end
end
