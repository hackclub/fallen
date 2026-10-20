# Handles the "say_hello" button posted by /ping.
class SayHelloAction < SlackBot::Action
  def call
    say ":wave: <@#{slack_user_id}> says hi! (via `app/bot/say_hello_action.rb`)"
    update_message("Said hi for you :white_check_mark:")
  end
end
