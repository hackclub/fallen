# The desktop pet picked at the end of onboarding. Only ever the signed-in user's own.
class PetsController < ApplicationController
  allow_trial_access only: :update # Picking a pet finishes the onboarding
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #update authorizes explicitly

  def update
    authorize current_user, :choose_pet?
    if current_user.update(pet: params.require(:pet))
      redirect_back fallback_location: home_path
    else
      redirect_back fallback_location: home_path, alert: "That pet doesn't exist."
    end
  end
end
