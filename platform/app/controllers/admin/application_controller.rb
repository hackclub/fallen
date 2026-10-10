class Admin::ApplicationController < ApplicationController
  before_action :require_admin!

  private

  def require_admin!
    raise ActionController::RoutingError, "Not Found" unless current_user&.admin?
  end
end
