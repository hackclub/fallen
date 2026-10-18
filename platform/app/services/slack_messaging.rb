# frozen_string_literal: true

# Posts to Slack as a person, with the user token they granted in SlackAuthController. Nothing is written on
# their behalf without it: the web side refuses to journal until Slack is connected (ProjectPolicy, JournalPolicy).
# Project anchors and journals are written here; the Slack-side handlers in app/bot read them back.
module SlackMessaging
  class NotConfigured < StandardError; end
  class NotConnected < StandardError; end

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

  # Returns the posted message's ts. A user token can only post where its owner is a member, so someone who never
  # joined the channel (or left it) is invited by the bot and the post is tried once more.
  def post(user, channel:, text:, blocks: nil, thread_ts: nil)
    invited = false
    as(user) do |client|
      client.chat_postMessage({ channel: channel, text: text, blocks: blocks, thread_ts: thread_ts, unfurl_links: false, unfurl_media: true }.compact).ts
    rescue Slack::Web::Api::Errors::NotInChannel
      raise if invited || user.slack_id.blank?

      invite(user, channel)
      invited = true
      retry
    end
  end

  def invite(user, channel)
    SlackBot.client.conversations_invite(channel: channel, users: user.slack_id)
  rescue Slack::Web::Api::Errors::AlreadyInChannel
    nil
  end

  def update(user, channel:, ts:, text:, blocks: nil)
    as(user) { |client| client.chat_update({ channel: channel, ts: ts, text: text, blocks: blocks }.compact) }
  end

  def delete(user, channel:, ts:)
    as(user) { |client| client.chat_delete(channel: channel, ts: ts) }
  rescue Slack::Web::Api::Errors::MessageNotFound
    nil
  end

  def client_for(user) = Slack::Web::Client.new(token: user.slack_user_token)

  def as(user)
    raise NotConfigured, "SLACK_BOT_TOKEN is not set" unless SlackBot.configured?
    raise NotConnected, "#{user.public_id} has not connected Slack" unless user.slack_connected?

    yield client_for(user)
  rescue Slack::Web::Api::Errors::TokenRevoked, Slack::Web::Api::Errors::InvalidAuth, Slack::Web::Api::Errors::AccountInactive => e
    user.disconnect_slack!
    raise NotConnected, "#{user.public_id}'s Slack token stopped working (#{e.message})"
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
