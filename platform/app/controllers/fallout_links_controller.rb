# Fallout's emails link to /?email=…&code=… (config/routes.rb). When the code is the one Fallout has for that email
# (FalloutInvite), the visitor gets a trial account without typing anything, like TrialSessionsController. The code
# never changes, so a bad one only lands on the page (Rack::Attack limits guesses), and the params leave the address bar
# in the redirect. An existing trial account is only picked up when nobody else can hold a session for it: this
# browser's own, or one the Slack join button made. A trial made from the email form may be someone else's, and
# signing in with Hack Club Auth turns it into the real account in place.
class FalloutLinksController < ApplicationController
  include TrialCookie

  allow_unauthenticated_access only: :show # The link is how a signed-out Fallout participant gets in
  allow_trial_access only: :show # A trial account clicking it again goes home
  skip_after_action :verify_authorized # Acts only on the current session
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  def show
    return redirect_to home_path if user_signed_in?

    email = params[:email].to_s.strip.downcase
    return redirect_to root_path, alert: "That link didn't work. You can still get started with your email." unless FalloutInvite.match?(email, params[:code])
    return redirect_to sign_in_path(login_hint: email) if User.kept.verified.exists?(email: email)

    user = remembered_trial(email) || User.kept.trial.where.not(slack_id: nil).find_by(email: email) ||
      User.start_trial!(email: email, signup_source: take_signup_source)
    remember_trial(user)
    sign_in(user)
    redirect_to after_sign_in_path
  end
end
