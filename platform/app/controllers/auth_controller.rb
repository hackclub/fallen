class AuthController < ApplicationController
  include OauthState

  allow_unauthenticated_access only: %i[new create] # The OAuth flow runs before there is a session
  skip_before_action :redirect_banned_user!, only: :destroy # Banned users must still be able to sign out
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Acts only on the current session
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to root_path, alert: "Too many attempts, try again in a few minutes." }

  def new
    return redirect_to root_path, alert: "Hack Club Auth is not configured (HCA_CLIENT_ID / HCA_CLIENT_SECRET)." unless HCA.configured?

    redirect_to HCA.authorize_url(hca_callback_url, issue_oauth_state), allow_other_host: true
  end

  def create
    unless consume_oauth_state(params[:state])
      Rails.logger.warn({ event: "auth.state_mismatch" }.to_json)
      return redirect_to root_path, alert: "Sign in failed (state mismatch). Please try again."
    end

    return redirect_to root_path, alert: "Sign in was cancelled." if params[:error].present?

    user = User.from_hca_code!(params[:code], hca_callback_url)
    sign_in(user)
    Rails.logger.info({ event: "auth.signed_in", user_id: user.id }.to_json)
    redirect_to after_sign_in_path, notice: "Welcome back, #{user.display_name}!"
  rescue HCA::Error, Faraday::Error, ActiveRecord::RecordInvalid => e
    Sentry.capture_exception(e)
    Rails.logger.error({ event: "auth.failed", error: e.message }.to_json)
    redirect_to root_path, alert: "Sign in failed: #{e.message}"
  end

  def destroy
    sign_out
    redirect_to root_path, notice: "Signed out. See you soon!"
  end
end
