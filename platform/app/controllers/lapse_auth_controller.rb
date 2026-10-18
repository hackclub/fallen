# "Connect Lapse": a token to list the person's timelapses, so a journal can take its hours from one.
class LapseAuthController < ApplicationController
  include OauthState

  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Acts only on the current user
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to projects_path, alert: "Too many attempts, try again in a few minutes." }

  def new
    return redirect_to return_path, alert: "Lapse sign-in is not configured (LAPSE_CLIENT_ID / LAPSE_CLIENT_SECRET)." unless Lapse.configured?

    session[:return_to] = params[:return_to] if params[:return_to].present? && params[:return_to].start_with?("/")
    state = issue_oauth_state
    redirect_to Lapse.authorize_url(callback_url, state, code_verifier: code_verifier(state)), allow_other_host: true
  end

  def create
    return redirect_to return_path, alert: "Connecting Lapse failed (state mismatch). Please try again." unless consume_oauth_state(params[:state])
    return redirect_to return_path, alert: "Connecting Lapse was cancelled." if params[:error].present?

    token = Lapse.exchange_code(params[:code], callback_url, code_verifier: code_verifier(params[:state]))
    current_user.update!(lapse_token: token)
    SyncLapseTimelapsesJob.perform_later(current_user)
    redirect_to return_path, notice: "Lapse connected. Pick a timelapse when you journal and its time becomes your hours."
  rescue Lapse::Error, Faraday::Error => e
    Sentry.capture_exception(e)
    redirect_to return_path, alert: "Connecting Lapse failed: #{e.message}"
  end

  def destroy
    current_user.disconnect_lapse!
    redirect_back fallback_location: settings_path, notice: "Lapse disconnected. Journals you already wrote keep their timelapses."
  end

  private

  def return_path = session.delete(:return_to).presence || settings_path

  # PKCE verifier tied to the OAuth state, so the state cookie is all the flow needs to remember.
  def code_verifier(state) = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "lapse-pkce:#{state}")

  # Lapse only redirects to registered URLs, which are built from APP_URL.
  def callback_url = ENV["APP_URL"].present? ? "#{ENV['APP_URL'].chomp('/')}/auth/lapse/callback" : lapse_callback_url
end
