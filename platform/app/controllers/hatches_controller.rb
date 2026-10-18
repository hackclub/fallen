# Called by the site when the hatch finishes playing (components/hatch/HatchOverlay.svelte). Only ever the signed-in
# user's own.
class HatchesController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #create authorizes explicitly

  def create
    authorize current_user, :watch_hatch?
    current_user.hatch_seen!
    redirect_back fallback_location: home_path
  end
end
