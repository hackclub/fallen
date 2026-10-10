class Admin::UsersController < Admin::ApplicationController
  before_action :set_user, except: :index

  def index
    scope = policy_scope(User)
    scope = scope.search(params[:query]) if params[:query].present?
    @pagy, users = pagy(scope.order(created_at: :desc))

    render inertia: "Admin/Users/Index", props: {
      users: AdminUserSerializer.render(users),
      pagy: pagy_props(@pagy),
      query: params[:query].to_s
    }
  end

  def show
    authorize @user

    render inertia: "Admin/Users/Show", props: {
      user: AdminUserDetailSerializer.render(@user),
      roles: User::ROLES,
      can: { update: policy(@user).update?, impersonate: policy(@user).impersonate? }
    }
  end

  def update
    authorize @user

    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: "User updated."
    else
      inertia_errors(@user, fallback_location: admin_user_path(@user))
    end
  end

  # See the app exactly as this user does. The real admin stays in session[:impersonator_id]
  # and is restored by ImpersonationsController#destroy.
  def impersonate
    authorize @user

    Rails.logger.info({ event: "impersonation.start", admin_id: current_user.id, user_id: @user.id, ip: request.remote_ip }.to_json)
    session[:impersonator_id] = current_user.id
    session[:user_id] = @user.id
    redirect_to home_path, notice: "You are now browsing as #{@user.display_name}."
  end

  private

  def set_user
    @user = User.find_by_public_id!(params[:id])
  end

  def user_params
    params.expect(user: [ :is_banned, roles: [] ])
  end
end
