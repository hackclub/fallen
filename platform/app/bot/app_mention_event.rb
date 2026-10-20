# Replies in a thread whenever someone @mentions the bot.
class AppMentionEvent < SlackBot::Event
  def call
    return if from_bot?

    if user
      reply ":wave: Hi #{SlackMessages.escape(user.display_name)}! You're signed in as `#{user.public_id}`."
    else
      reply ":wave: Hi <@#{slack_user_id}>! Sign in at #{ENV.fetch('APP_URL', 'http://localhost:3000')} to link your account."
    end
  end
end
