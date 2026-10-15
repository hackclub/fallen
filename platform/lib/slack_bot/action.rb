# frozen_string_literal: true

module SlackBot
  # Block Kit interaction (buttons, selects...). app/bot/say_hello_action.rb handles action_id "say_hello".
  # Action IDs may carry data after a colon: "say_hello:123" still routes here, with `arg` == "123".
  class Action < Handler
    def action = payload.actions&.first
    def action_id = action&.action_id
    def value = action&.value
    def selected_option = action&.selected_option
    def arg = action_id.to_s.split(":", 2)[1]
    def message = payload.message
    def message_ts = message&.ts || payload.dig("container", "message_ts")
    def thread_ts = message&.thread_ts

    # { "action_id" => value } for the input blocks in the message the action came from.
    def input_values
      @input_values ||= (payload.dig("state", "values")&.to_h || {}).values.reduce({}, :merge).transform_values do |input|
        input["value"] || input.dig("selected_option", "value") || input["selected_options"]&.map { |o| o["value"] }
      end
    end

    # Replaces the message that contained the action.
    def update_message(text = nil, blocks: nil, **options)
      respond(text, blocks: blocks, replace_original: true, **options)
    end

    def delete_message = respond(delete_original: true)
  end
end
