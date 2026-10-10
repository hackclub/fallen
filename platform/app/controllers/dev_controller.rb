# Development/test-only helpers. Not routed in production (see config/routes.rb).
class DevController < ApplicationController
  allow_unauthenticated_access only: :sign_in_as
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Local-only, no resource

  def sign_in_as
    raise ActionController::RoutingError, "Not Found" unless Rails.env.local?

    user = User.find_by(id: params[:id]) || User.find_by_public_id(params[:id]) || User.find_by!(email: params[:id])
    sign_in(user)
    redirect_to home_path, notice: "Signed in as #{user.display_name} (dev only)."
  end
end
