# Fallout's emails link to /?email=…&code=… (config/routes.rb). When the code is the one Fallout has for that email
# (FalloutInvite), it is a soft signup like the Slack join button: a trial account is made for the email
# (User.join_from_fallout!) and nobody is signed in here. Every link lands on the page the same way, made or not, with
# the email and code gone from the address bar; Rack::Attack limits guesses. The page then sends someone already signed
# in to Hack Club Auth straight on to sign in with it (`continue_with_hca`), which claims the account by email.
class FalloutLinksController < ApplicationController
  allow_unauthenticated_access only: :show # Fallout participants follow it signed out
  allow_trial_access only: :show # It never touches the session
  skip_after_action :verify_authorized # Acts on no one's records but the email's owner, proven by the code
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  def show
    email = params[:email].to_s.strip.downcase
    User.join_from_fallout!(email, signup_source: link_source) if FalloutInvite.match?(email, params[:code])
    redirect_to root_path, flash: { continue_with_hca: true }
  end

  private

  def link_source
    SignupSource::PARAMS.index_with { params[it] }.select { |_, value| value.is_a?(String) && value.present? }
      .transform_values { it.truncate(SignupSource::MAX_LENGTH) }
  end
end
