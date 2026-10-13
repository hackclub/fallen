# /fallen-feedback opens a modal (/feedback is taken in the Hack Club workspace); the submission is handled by FeedbackView.
class FallenFeedbackCommand < SlackBot::Command
  description "Send feedback to the team"

  def call
    open_modal modal(
      "Send feedback",
      [
        input("What's on your mind?", plain_text_input("message", multiline: true, placeholder: "Be as specific as you like"), block_id: "message"),
        input("How urgent is it?", static_select("urgency", [ [ "Just a thought", "low" ], [ "Soon please", "medium" ], [ "On fire", "high" ] ]), block_id: "urgency", optional: true)
      ],
      callback_id: "feedback",
      private_metadata: channel_id
    )
  end
end
