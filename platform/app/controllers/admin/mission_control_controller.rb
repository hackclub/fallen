# Base class for the Mission Control (Solid Queue dashboard) engine mounted at /admin/jobs.
# Access is enforced by Constraints::Admin in routes and require_admin! in Admin::ApplicationController.
class Admin::MissionControlController < Admin::ApplicationController
  skip_after_action :verify_authorized # Engine controllers have no Pundit policies
  skip_after_action :verify_policy_scoped
end
