# /ping. The smallest possible slash command. Try `/ping loud` to post in the channel.
class PingCommand < SlackBot::Command
  description "Check that the bot is alive"
  usage_hint "[loud]"

  def call
    greeting = user ? "Hey #{SlackMessages.escape(user.display_name)}!" : "Hey! You haven't signed in to Fallen yet."

    respond(
      "pong :table_tennis_paddle_and_ball:",
      in_channel: args.include?("loud"),
      blocks: [
        section(":table_tennis_paddle_and_ball: *pong*. #{greeting}"),
        actions(button("Say hi in channel", "say_hello", value: slack_user_id)),
        context("Handled by `app/bot/ping_command.rb`")
      ]
    )
  end
end
