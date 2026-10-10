# Exit path for admin impersonation. Lives outside /admin because while impersonating, current_user is
# the (non-admin) target and the admin constraint would lock the admin out of stopping.
class ImpersonationsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Acts only on the current session

  def destroy
    return redirect_to root_path unless impersonating?

    target = current_user
    Rails.logger.info({ event: "impersonation.stop", admin_id: true_user.id, user_id: target.id }.to_json)
    session[:user_id] = session.delete(:impersonator_id)
    redirect_to admin_user_path(target), notice: "Stopped impersonating #{target.display_name}."
  end
end
