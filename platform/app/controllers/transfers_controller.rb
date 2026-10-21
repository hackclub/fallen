class TransfersController < ApplicationController
  skip_after_action :verify_authorized # Static page, no records
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  def show
    render inertia: "Transfers/Show"
  end
end
