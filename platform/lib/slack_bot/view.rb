# frozen_string_literal: true

module SlackBot
  # Modal submission/close. app/bot/feedback_view.rb handles callback_id "feedback".
  #
  #   def call
  #     return errors(message: "Say a bit more") if values["message"].to_s.length < 10
  #     Feedback.create!(user: user, body: values["message"])
  #     close
  #   end
  class View < Handler
    def view = payload.view
    def closed? = payload.type == "view_closed"
    def private_metadata = view&.private_metadata

    # { "block_id" => value } for every input in the modal.
    def values
      @values ||= (view&.dig("state", "values")&.to_h || {}).transform_values do |actions|
        action = actions.values.first || {}
        action["value"] || action.dig("selected_option", "value") || action["selected_date"] ||
          action["selected_user"] || action["selected_conversation"] || action["selected_channel"] ||
          action["selected_options"]&.map { |o| o["value"] } || action["selected_users"]
      end
    end

    # --- submission responses (inline) ---------------------------------------------------------

    def errors(**field_errors) = respond_inline(response_action: "errors", errors: field_errors.transform_keys(&:to_s))
    def update_view(new_view) = respond_inline(response_action: "update", view: new_view)
    def push_view(new_view) = respond_inline(response_action: "push", view: new_view)
    def close_all = respond_inline(response_action: "clear")
    def close = @inline_response = nil

    private

    def inline_response_allowed? = true
  end
end
