# "No thanks" on the project nudge: removes the ephemeral message.
class DismissNudgeAction < SlackBot::Action
  def call = delete_message
end
