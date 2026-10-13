# Receives the modal opened by /fallen-feedback. Return `errors(...)` to show validation errors inline.
class FeedbackView < SlackBot::View
  def call
    message = values["message"].to_s.strip
    return errors(message: "Tell us a bit more (10+ characters).") if message.length < 10

    Rails.logger.info({ event: "feedback.received", slack_user_id: slack_user_id, user_id: user&.id, urgency: values["urgency"], message: message }.to_json)

    ephemeral(":mailbox_with_mail: Thanks, got it!", channel: private_metadata) if private_metadata.present?
    close
  end
end
