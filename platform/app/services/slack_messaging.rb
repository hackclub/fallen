# frozen_string_literal: true

# Posts to Slack as a person: with the user token they granted in SlackAuthController, or, if they skipped that, by
# the bot under their name and picture (chat:write.customize). The web side refuses to journal until they have done
# one or the other (User#slack_ready?). Project anchors and journals are written here; the Slack-side handlers in
# app/bot read them back.
module SlackMessaging
  class NotConfigured < StandardError; end
  class NotConnected < StandardError; end
  # Their Slack account was deactivated, so the bot doesn't post for them either.
  class Deactivated < NotConnected; end

  # `by_bot` is stored with the message: only whoever posted it can edit or delete it.
  Posted = Data.define(:ts, :by_bot)

  module_function

  def journals_channel_id = ENV["SLACK_JOURNALS_CHANNEL_ID"].presence

  def configured? = SlackBot.configured? && journals_channel_id.present?

  def oauth_configured? = ENV["SLACK_CLIENT_ID"].present? && ENV["SLACK_CLIENT_SECRET"].present?

  # Links name the workspace. A bare slack.com or app.slack.com link opens whichever workspace the person last used,
  # so anyone also signed in to another one lands on Slack's error page.
  WORKSPACE_URL = "https://hackclub.slack.com"

  def permalink(channel_id, ts, thread_ts: nil)
    url = "#{WORKSPACE_URL}/archives/#{channel_id}/p#{ts.to_s.delete('.')}"
    thread_ts.present? && thread_ts != ts ? "#{url}?thread_ts=#{thread_ts}&cid=#{channel_id}" : url
  end

  # A user token can only post where its owner is a member, so someone who never joined the channel (or left it) is
  # invited by the bot and the post is tried once more. A token that stopped working falls back to the bot for
  # someone who chose it before (User#slack_skipped?).
  def post(user, channel:, text:, blocks: nil, attachments: nil, thread_ts: nil)
    message = { channel: channel, text: text, blocks: blocks, attachments: attachments, thread_ts: thread_ts, unfurl_links: false, unfurl_media: true }.compact
    return post_as_bot(user, message) unless user.slack_connected?

    begin
      Posted.new(ts: post_as_user(user, message), by_bot: false)
    rescue NotConnected => e
      raise if e.is_a?(Deactivated) || !user.slack_skipped?

      post_as_bot(user, message)
    end
  end

  def update(user, channel:, ts:, text:, by_bot:, blocks: nil, attachments: nil)
    message = { channel: channel, ts: ts, text: text, blocks: blocks, attachments: attachments }.compact
    by_bot ? bot_client.chat_update(message) : as(user) { |client| client.chat_update(message) }
  end

  def delete(user, channel:, ts:, by_bot:)
    by_bot ? bot_client.chat_delete(channel: channel, ts: ts) : as(user) { |client| client.chat_delete(channel: channel, ts: ts) }
  rescue Slack::Web::Api::Errors::MessageNotFound
    nil
  end

  def invite(user, channel)
    SlackBot.client.conversations_invite(channel: channel, users: user.slack_id)
  rescue Slack::Web::Api::Errors::AlreadyInChannel
    nil
  end

  # Slack shows the name and picture with an APP tag, so nobody mistakes it for the person writing in Slack.
  def persona(user)
    icon = user.avatar_url if user.avatar_url.start_with?("https://")
    { username: user.display_name, icon_url: icon || SlackMessages::PET_PFPS[user.pet] }.compact
  end

  def client_for(user) = Slack::Web::Client.new(token: user.slack_user_token)

  def as(user)
    raise NotConfigured, "SLACK_BOT_TOKEN is not set" unless SlackBot.configured?
    raise NotConnected, "#{user.public_id} has not connected Slack" unless user.slack_connected?

    yield client_for(user)
  rescue Slack::Web::Api::Errors::AccountInactive => e
    user.disconnect_slack!
    raise Deactivated, "#{user.public_id}'s Slack account is deactivated (#{e.message})"
  rescue Slack::Web::Api::Errors::TokenRevoked, Slack::Web::Api::Errors::InvalidAuth => e
    user.disconnect_slack!
    raise NotConnected, "#{user.public_id}'s Slack token stopped working (#{e.message})"
  end

  def post_as_user(user, message)
    invited = false
    as(user) do |client|
      client.chat_postMessage(message).ts
    rescue Slack::Web::Api::Errors::NotInChannel
      raise if invited || user.slack_id.blank?

      invite(user, message[:channel])
      invited = true
      retry
    end
  end

  # Someone whose Slack account was deactivated (banned from the workspace, say) is not posted for, so skipping
  # Slack is no way around that. Without a Slack account there is nothing to look up.
  def post_as_bot(user, message)
    raise NotConnected, "#{user.public_id} has neither connected nor skipped Slack" unless user.slack_skipped?
    raise Deactivated, "#{user.public_id}'s Slack account is deactivated" if user.slack_id.present? && bot_client.users_info(user: user.slack_id).user&.deleted

    Posted.new(ts: bot_client.chat_postMessage(**message, **persona(user)).ts, by_bot: true)
  end

  def bot_client
    raise NotConfigured, "SLACK_BOT_TOKEN is not set" unless SlackBot.configured?

    SlackBot.client
  end

  # --- user OAuth ("Connect Slack") -----------------------------------------------------------

  USER_SCOPES = %w[chat:write].freeze

  # SLACK_TEAM_ID pins the workspace; on Enterprise Grid Slack otherwise stops to ask which one.
  def authorize_url(redirect_uri, state)
    params = { client_id: ENV.fetch("SLACK_CLIENT_ID"), user_scope: USER_SCOPES.join(","), redirect_uri: redirect_uri, state: state, team: ENV["SLACK_TEAM_ID"].presence }.compact
    "https://slack.com/oauth/v2/authorize?#{params.to_query}"
  end

  # Returns { "id" => "U…", "access_token" => "xoxp-…", "scope" => "chat:write" } for the user who authorised.
  # When the same authorisation also installed the bot (an admin ran the install URL with bot scopes),
  # the bot token is written to tmp/ in development so it can be copied into .env.development.
  def exchange_code(code, redirect_uri)
    response = Slack::Web::Client.new(token: nil).oauth_v2_access(
      client_id: ENV.fetch("SLACK_CLIENT_ID"), client_secret: ENV.fetch("SLACK_CLIENT_SECRET"),
      code: code, redirect_uri: redirect_uri
    )
    if Rails.env.development? && response.access_token.present?
      Rails.root.join("tmp/slack_install.json").write({ bot_token: response.access_token, team: response.team&.to_h, scope: response.scope }.to_json)
    end
    response.authed_user.to_h
  end

  # The "Add to Slack" URL for installing the bot into a workspace (plus the user token in the same step).
  def install_url(redirect_uri, state)
    params = { client_id: ENV.fetch("SLACK_CLIENT_ID"), scope: SlackBot::Manifest::BOT_SCOPES.join(","), user_scope: USER_SCOPES.join(","), redirect_uri: redirect_uri, state: state }
    "https://slack.com/oauth/v2/authorize?#{params.to_query}"
  end

  def revoke(user)
    Slack::Web::Client.new(token: user.slack_user_token).auth_revoke
  rescue Slack::Web::Api::Errors::SlackError
    nil
  end
end
