class LandingController < ApplicationController
  allow_unauthenticated_access only: :index # Public landing page
  skip_after_action :verify_authorized # No resource to authorize
  skip_after_action :verify_policy_scoped # Nothing to scope

  def index
    return redirect_to home_path if user_signed_in?

    render inertia: "Landing/Index", props: { hca_configured: HCA.configured?, dev_users: dev_users }
  end

  private

  # Development/test only: lets you sign in without Hack Club Auth (see DevController and db/seeds.rb).
  def dev_users
    return nil unless Rails.env.local?

    DevUserSerializer.render(User.kept.order(:id))
  end
end
