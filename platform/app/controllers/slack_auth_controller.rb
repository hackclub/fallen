# "Connect Slack": a user token so journals written on the web land in Slack as the person. Skipping it has the bot
# post them under the person's name and picture instead (SlackMessaging.post).
class SlackAuthController < ApplicationController
  include OauthState

  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Acts only on the current user
  rate_limit to: 10, within: 3.minutes, only: :create, by: -> { current_user.id }, with: -> { redirect_to projects_path, alert: "Too many attempts, try again in a few minutes." }

  def new
    return redirect_to projects_path, alert: "Slack sign-in is not configured (SLACK_CLIENT_ID / SLACK_CLIENT_SECRET)." unless SlackMessaging.oauth_configured?

    remember_return_to(params[:return_to])
    # ?install=1 (admins) also installs the bot into the workspace; everyone else only grants their user token.
    url = params[:install].present? && current_user.admin? ? SlackMessaging.install_url(callback_url, issue_oauth_state) : SlackMessaging.authorize_url(callback_url, issue_oauth_state)
    redirect_to url, allow_other_host: true
  end

  def create
    return redirect_to return_path, alert: "Connecting Slack failed (state mismatch). Please try again." unless consume_oauth_state(params[:state])
    return redirect_to return_path, alert: "Connecting Slack was cancelled." if params[:error].present?

    authed = SlackMessaging.exchange_code(params[:code], callback_url)
    # Whichever account they connect wins over the one on their Hack Club account: some people have two, and the
    # one HCA knows is not always the one they use.
    # The bot finds people by Slack ID, so a second account on the same ID would make their Slack replies go nowhere.
    if User.kept.where(slack_id: authed["id"]).where.not(id: current_user.id).exists?
      return redirect_to return_path, alert: "That Slack account is already connected to another Fallen account."
    end

    current_user.update!(slack_id: authed["id"], slack_user_token: authed["access_token"], slack_user_token_scopes: authed["scope"])
    SyncSlackProfileJob.perform_later(current_user)
    post_waiting_projects
    redirect_to return_path, notice: "Slack connected. Journals you write here now post as you."
  rescue Slack::Web::Api::Errors::SlackError, Faraday::Error => e
    Sentry.capture_exception(e)
    redirect_to return_path, alert: "Connecting Slack failed: #{e.message}"
  end

  def skip
    current_user.skip_slack!
    post_waiting_projects
    redirect_back fallback_location: projects_path, notice: "Skipped. Fallen will post your journals in Slack under your name."
  end

  # Disconnecting is choosing the bot, so they are not asked again.
  def destroy
    SlackMessaging.revoke(current_user) if current_user.slack_connected?
    current_user.disconnect_slack!
    current_user.skip_slack!
    redirect_back fallback_location: projects_path, notice: "Slack disconnected. Journals will post through the bot."
  end

  private

  def return_path = take_return_to || projects_path

  # Also what never got posted because their token stopped working (SyncJournalToSlackJob drops those). Projects
  # without a thread post their own journals once it exists.
  def post_waiting_projects
    current_user.projects.kept.where(slack_thread_ts: nil).find_each { |project| PostProjectToSlackJob.perform_later(project) }
    journals = current_user.journals.kept.where(slack_ts: nil, project: Project.kept.where.not(slack_thread_ts: nil))
    journals.find_each { |journal| SyncJournalToSlackJob.perform_later(journal, "create") }
  end

  # Slack only redirects to the URLs in the manifest, which are built from APP_URL, so use that rather than
  # whatever host this request came in on.
  def callback_url = ENV["APP_URL"].present? ? "#{ENV['APP_URL'].chomp('/')}/auth/slack/callback" : slack_callback_url
end
