class SettingsController < ApplicationController
  include SlackStatus

  skip_after_action :verify_authorized # Shows only the current user's own settings
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  def show
    render inertia: "Settings/Show", props: { slack: slack_props, timezone: current_user.timezone }
  end
end
