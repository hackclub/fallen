# Getting started with just an email, for people without a Hack Club Auth account yet: the landing page asks HCA
# first and only comes here when it has never heard of the email. The account can do the onboarding and make a
# project, then signs in with HCA to go on (Authentication#authenticate_verified_user!, User.from_hca_code!).
class TrialSessionsController < ApplicationController
  include TrialCookie

  allow_unauthenticated_access only: :create # This is how a signed-out visitor gets an account
  allow_trial_access only: :create # A trial account entering another email starts again
  skip_after_action :verify_authorized # Acts only on the current session
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  def create
    return redirect_to home_path if user_signed_in? && !current_user.trial?

    email = params[:email].to_s.strip.downcase
    return redirect_to root_path, alert: "That doesn't look like an email." unless email.match?(URI::MailTo::EMAIL_REGEXP)
    return inertia_location(sign_in_path(login_hint: email)) if User.kept.verified.exists?(email: email)

    user = remembered_trial(email) || User.start_trial!(email: email, signup_source: take_signup_source)
    remember_trial(user)
    sign_in(user)
    redirect_to after_sign_in_path
  end
end
