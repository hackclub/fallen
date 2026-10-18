class BansController < ApplicationController
  allow_trial_access only: :show # Banned trial accounts land here too
  allow_unauthenticated_access only: :show # Banned users have no other page to land on
  skip_before_action :redirect_banned_user!, only: :show # This is where banned users are redirected to
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # No resource to authorize

  def show
    return redirect_to root_path unless current_user&.is_banned?

    render inertia: "Bans/Show"
  end
end
