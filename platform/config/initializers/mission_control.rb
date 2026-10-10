# frozen_string_literal: true

# Job dashboard at /admin/jobs. Access is gated by Constraints::Admin in routes and Admin::ApplicationController.
MissionControl::Jobs.http_basic_auth_enabled = false
MissionControl::Jobs.base_controller_class = "Admin::MissionControlController"
