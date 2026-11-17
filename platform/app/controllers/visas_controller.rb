class VisasController < ApplicationController
  allow_trial_access only: :show # Worth checking before signing up
  allow_unauthenticated_access only: :show # Shareable with parents and people deciding whether to join
  skip_after_action :verify_authorized # Static page, no records
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  def show
    render inertia: "Visas/Show"
  end
end
