# frozen_string_literal: true

# Slack profile pictures found by email, for greeting someone who is signed in to Hack Club Auth but not yet to
# Fallen. Requests only read the cache; SlackAvatarJob asks Slack. Keys are digests, so the cache never holds the
# email. Uses its own app's bot token (SLACK_LOOKUP_TOKEN, users:read and users:read.email), so the main bot, which
# people sign in through, never gets to read emails.
module SlackAvatars
  PENDING = "pending"
  KEEP_FOR = 1.day
  # Pictures people upload. Without one, Slack links their email's Gravatar with its silhouette as the fallback, so
  # Slack's is_custom_image is true for that too. Asking Gravatar with d=404 tells a real Gravatar from the silhouette.
  UPLOADED_HOST = "avatars.slack-edge.com"
  GRAVATAR_HOST = "secure.gravatar.com"

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
    Rails.cache.write(key_for(email), own_picture(user.profile.image_192.to_s).to_s, expires_in: KEEP_FOR)
  rescue Slack::Web::Api::Errors::UsersNotFound, Slack::Web::Api::Errors::UserNotFound
    Rails.cache.write(key_for(email), "", expires_in: KEEP_FOR)
  end

  def own_picture(url)
    uri = URI(url)
    return url if uri.host == UPLOADED_HOST
    return unless uri.host == GRAVATAR_HOST

    uri.query = URI.decode_www_form(uri.query.to_s).to_h.merge("d" => "404").to_query
    uri.to_s if gravatar?(uri)
  end

  def gravatar?(uri) = Faraday.new { |f| f.options.timeout = 5 }.head(uri).success?

  def client = @client ||= Slack::Web::Client.new(token: ENV.fetch("SLACK_LOOKUP_TOKEN"))

  def key_for(email) = "slack_avatar/#{Digest::SHA256.hexdigest(email)}"
end
