class ShopController < ApplicationController
  allow_trial_access only: :show # Nothing to buy yet, so nothing to sign up for
  skip_after_action :verify_authorized # Static page, no records
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  def show
    render inertia: "Shop/Show"
  end
end
