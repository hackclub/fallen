# Development/test-only sign in, standing in for Hack Club Auth. Not routed in production (see config/routes.rb).
class DevController < ApplicationController
  allow_unauthenticated_access only: %i[index create sign_in_as] # Signing in is what these are for
  skip_before_action :redirect_banned_user!, only: %i[index create sign_in_as] # So a banned test account can switch away
  skip_after_action :verify_policy_scoped # Local-only: lists every account on purpose
  skip_after_action :verify_authorized # Local-only, no resource
  before_action :local_only!

  USERS_SHOWN = 50

  def index
    users = params[:q].present? ? User.kept.search(params[:q]) : User.kept.order(Arel.sql("last_seen_at DESC NULLS LAST"), id: :desc)
    render inertia: "Dev/Index", props: {
      users: DevUserSerializer.render(users.limit(USERS_SHOWN)),
      query: params[:q].to_s,
      roles: User::ROLES,
      pets: User::PETS,
      hca_configured: HCA.configured?
    }
  end

  # A brand new account, as if someone had just signed in with Hack Club Auth for the first time. Also reachable as
  # GET /dev/sign_in_as/new?roles[]=admin&pet=lulu for scripts and bookmarks.
  def create
    user = User.new(new_user_attributes)
    return redirect_to dev_path, alert: user.errors.full_messages.to_sentence unless user.save

    sign_in(user)
    redirect_to after_sign_in_path, notice: "Signed in as new account #{user.display_name} (dev only)."
  end

  def sign_in_as
    user = User.find_by(id: params[:id]) || User.find_by_public_id(params[:id]) || User.find_by!(email: params[:id])
    sign_in(user)
    redirect_to after_sign_in_path, notice: "Signed in as #{user.display_name} (dev only)."
  end

  private

  def local_only!
    raise ActionController::RoutingError, "Not Found" unless Rails.env.local?
  end

  def new_user_attributes
    tag = SecureRandom.hex(3)
    name = params[:display_name].presence || "Tester #{tag}"
    roles = Array(params[:roles]).compact_blank & User::ROLES
    {
      hca_id: "dev_#{tag}",
      display_name: name,
      email: params[:email].presence || "#{name.parameterize.presence || 'tester'}.#{tag}@example.com",
      roles: (%w[user] | roles),
      is_adult: ActiveModel::Type::Boolean.new.cast(params[:is_adult]) || false,
      is_banned: ActiveModel::Type::Boolean.new.cast(params[:is_banned]) || false,
      pet: params[:pet].presence
    }
  end
end
