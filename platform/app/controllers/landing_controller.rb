class LandingController < ApplicationController
  allow_unauthenticated_access only: :index # Public landing page
  skip_after_action :verify_authorized # No resource to authorize
  skip_after_action :verify_policy_scoped # Nothing to scope

  def index
    render inertia: "Landing/Index"
  end
end
