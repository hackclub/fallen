class LandingController < ApplicationController
  allow_unauthenticated_access only: :index # Public landing page
  skip_after_action :verify_authorized # No resource to authorize
  skip_after_action :verify_policy_scoped # Nothing to scope

  def index
    return redirect_to home_path if user_signed_in?

    render inertia: "Landing/Index", props: { hca_configured: HCA.configured? }
  end
end
