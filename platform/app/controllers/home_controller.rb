class HomeController < ApplicationController
  skip_after_action :verify_authorized # Shows only the current user's own data
  skip_after_action :verify_policy_scoped # Shows only the current user

  def index
    render inertia: "Home/Index", props: {
      user: UserProfileSerializer.render(current_user),
      slack_connected: SlackBot.configured?
    }
  end
end
