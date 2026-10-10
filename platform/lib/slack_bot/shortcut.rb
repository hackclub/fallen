# frozen_string_literal: true

module SlackBot
  # Global or message shortcut. app/bot/report_shortcut.rb handles callback_id "report".
  class Shortcut < Handler
    def callback_id = payload.callback_id
    def message = payload.message
    def message_shortcut? = payload.type == "message_action"
  end
end
