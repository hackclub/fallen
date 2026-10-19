class SettingsController < ApplicationController
  include SlackStatus
  include LapseStatus

  skip_after_action :verify_authorized # Shows only the current user's own settings
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  def show
    render inertia: "Settings/Show", props: {
      slack: slack_props, lapse: lapse_props, timezone: current_user.timezone, pet_switch: current_user.pet && pet_switch_props
    }
  end

  private

  def pet_switch_props
    switch = current_user.pet_switch
    { allowed: switch.allowed?, next_on: switch.next_on&.iso8601 }
  end
end
