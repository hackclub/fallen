# "Connect Slack": a user token so journals written on the web land in Slack as the person, not the bot.
class SlackAuthController < ApplicationController
  include OauthState

  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Acts only on the current user
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to projects_path, alert: "Too many attempts, try again in a few minutes." }

  def new
    return redirect_to projects_path, alert: "Slack sign-in is not configured (SLACK_CLIENT_ID / SLACK_CLIENT_SECRET)." unless SlackMessaging.oauth_configured?

    session[:return_to] = params[:return_to] if params[:return_to].present? && params[:return_to].start_with?("/")
    # ?install=1 (admins) also installs the bot into the workspace; everyone else only grants their user token.
    url = params[:install].present? && current_user.admin? ? SlackMessaging.install_url(callback_url, issue_oauth_state) : SlackMessaging.authorize_url(callback_url, issue_oauth_state)
    redirect_to url, allow_other_host: true
  end

  def create
    return redirect_to return_path, alert: "Connecting Slack failed (state mismatch). Please try again." unless consume_oauth_state(params[:state])
    return redirect_to return_path, alert: "Connecting Slack was cancelled." if params[:error].present?

    authed = SlackMessaging.exchange_code(params[:code], callback_url)
    if current_user.slack_id.present? && authed["id"] != current_user.slack_id
      return redirect_to return_path, alert: "That Slack account (#{authed['id']}) is not the one linked to your Hack Club account."
    end

    current_user.update!(slack_id: authed["id"], slack_user_token: authed["access_token"], slack_user_token_scopes: authed["scope"])
    SyncSlackProfileJob.perform_later(current_user)
    redirect_to return_path, notice: "Slack connected. Journals you write here now post as you."
  rescue Slack::Web::Api::Errors::SlackError, Faraday::Error => e
    Sentry.capture_exception(e)
    redirect_to return_path, alert: "Connecting Slack failed: #{e.message}"
  end

  def destroy
    SlackMessaging.revoke(current_user) if current_user.slack_connected?
    current_user.disconnect_slack!
    redirect_back fallback_location: projects_path, notice: "Slack disconnected. Journals will post through the bot."
  end

  private

  def return_path = session.delete(:return_to).presence || projects_path

  # Slack only redirects to the URLs in the manifest, which are built from APP_URL, so use that rather than
  # whatever host this request came in on.
  def callback_url = ENV["APP_URL"].present? ? "#{ENV['APP_URL'].chomp('/')}/auth/slack/callback" : slack_callback_url
end
