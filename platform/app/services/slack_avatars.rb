# frozen_string_literal: true

# Slack profile pictures found by email, for greeting someone who is signed in to Hack Club Auth but not yet to
# Fallen. Requests only read the cache; SlackAvatarJob asks Slack. Keys are digests, so the cache never holds the
# email. Uses its own app's bot token (SLACK_LOOKUP_TOKEN, users:read and users:read.email), so the main bot, which
# people sign in through, never gets to read emails.
module SlackAvatars
  PENDING = "pending"
  KEEP_FOR = 1.day
  # Pictures people upload. Slack's is_custom_image can't be trusted: it is true for a Gravatar URL that falls back
  # to Slack's default art.
  UPLOADED_HOST = "avatars.slack-edge.com"

  module_function

  def configured? = ENV["SLACK_LOOKUP_TOKEN"].present?

  # The picture's URL, nil when they have none of their own (or aren't in Slack), or :pending while the job looks.
  def fetch(email)
    return unless configured?

    key = key_for(email)
    case Rails.cache.read(key)
    in nil
      SlackAvatarJob.perform_later(email) if Rails.cache.write(key, PENDING, expires_in: 1.minute, unless_exist: true)
      :pending
    in PENDING then :pending
    in url then url.presence
    end
  end

  def look_up!(email)
    # Someone with a Fallen account may use another email on Slack, so the Slack account HCA linked comes first.
    slack_id = User.where(email: email).where.not(slack_id: nil).pick(:slack_id)
    user = slack_id ? client.users_info(user: slack_id).user : client.users_lookupByEmail(email: email).user
    url = user.profile.image_192.to_s
    Rails.cache.write(key_for(email), URI(url).host == UPLOADED_HOST ? url : "", expires_in: KEEP_FOR)
  rescue Slack::Web::Api::Errors::UsersNotFound, Slack::Web::Api::Errors::UserNotFound
    Rails.cache.write(key_for(email), "", expires_in: KEEP_FOR)
  end

  def client = @client ||= Slack::Web::Client.new(token: ENV.fetch("SLACK_LOOKUP_TOKEN"))

  def key_for(email) = "slack_avatar/#{Digest::SHA256.hexdigest(email)}"
end
