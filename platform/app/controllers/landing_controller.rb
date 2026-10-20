class LandingController < ApplicationController
  allow_unauthenticated_access only: :index # Public landing page
  allow_trial_access only: :index # Public landing page
  skip_after_action :verify_authorized # No resource to authorize
  skip_after_action :verify_policy_scoped # Nothing to scope

  def index
    render inertia: "Landing/Index", props: {
      whoami_url: "#{HCA.host}/api/external/whoami", check_email_url: HCA.check_email_url,
      email: params[:email].to_s.strip.first(254).presence, # /?email=… fills in the Get Started dialog
      # Arrived from a Fallout email link, and whether its soft signup waits for a person (FalloutLinksController)
      continue_with_hca: flash[:continue_with_hca].present?, pending_welcome: session[FalloutLinksController::SESSION_KEY].present?
    }
  end
end
