# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_user
    before_action :authenticate_user!
    before_action :redirect_banned_user!
    before_action :authenticate_verified_user!
    helper_method :current_user, :user_signed_in?, :true_user, :impersonating?
  end

  class_methods do
    # Relaxing directive: always pass `only:` so a new action stays protected by default.
    def allow_unauthenticated_access(only:)
      skip_before_action :authenticate_user!, only: only
    end

    # Trial accounts (User#trial?) are sent to Hack Club Auth from everything that doesn't opt in with this.
    def allow_trial_access(only:)
      skip_before_action :authenticate_verified_user!, only: only
    end
  end

  private

  def current_user = Current.user

  # The human behind the request: the admin while impersonating, otherwise current_user.
  def true_user = Current.true_user

  def user_signed_in? = current_user.present?

  def impersonating? = true_user.present? && true_user != current_user

  def set_current_user
    return if session[:user_id].blank?

    Current.user = User.kept.find_by(id: session[:user_id])
    Current.true_user = session[:impersonator_id] ? User.kept.find_by(id: session[:impersonator_id]) : Current.user
    Current.user&.touch_last_seen unless impersonating?
  end

  def authenticate_user!
    return if user_signed_in?

    session[:return_to] = request.fullpath if request.get? && !request.xhr?
    redirect_to root_path, alert: "You need to sign in first."
  end

  def redirect_banned_user!
    redirect_to sorry_path if current_user&.is_banned?
  end

  def authenticate_verified_user!
    return unless current_user&.trial?

    session[:return_to] = request.fullpath if request.get? && !request.xhr?
    url = sign_in_path(login_hint: current_user.email)
    request.inertia? ? inertia_location(url) : redirect_to(url)
  end

  def sign_in(user)
    return_to = session[:return_to]
    reset_session
    session[:user_id] = user.id
    session[:return_to] = return_to if return_to.present?
    Current.user = Current.true_user = user
  end

  def sign_out
    reset_session
    Current.user = Current.true_user = nil
  end

  def after_sign_in_path = session.delete(:return_to).presence || home_path
end
