class Admin::UsersController < Admin::ApplicationController
  # The latest timezone changes shown on a person's page.
  TIMEZONE_CHANGES = 20

  before_action :set_user, except: :index

  def index
    scope = policy_scope(User)
    scope = scope.kept unless include_deleted?
    scope = scope.search(params[:query]) if params[:query].present?

    # The filters render at once; the table fills in from a second request.
    render inertia: "Admin/Users/Index", props: {
      query: params[:query].to_s,
      include_deleted: include_deleted?,
      total_count: InertiaRails.defer(group: "table") { scope.count },
      **deferred_table(scope.order(created_at: :desc), AdminUserSerializer, :users)
    }
  end

  def show
    authorize @user
    projects = Project.kept.involving(@user).recent.includes(:user, memberships: :user).with_attached_banner.to_a

    streak = policy([ :admin, StreakAdjustment.new(user: @user) ])

    render inertia: "Admin/Users/Show", props: {
      user: AdminUserDetailSerializer.render(@user),
      projects: AdminProjectSerializer.render(projects, **Project.journal_totals(projects)),
      roles: User::ROLES,
      can: { update: policy(@user).update?, impersonate: policy(@user).impersonate?, streak: streak.create? },
      streak_blocked: streak.why_not,
      streak: InertiaRails.defer(group: "streak") { AdminStreakSerializer.render(StreakCalendar.new(@user)) },
      timezone_changes: InertiaRails.defer(group: "streak") do
        AdminTimezoneChangeSerializer.render(@user.timezone_changes.order(created_at: :desc).limit(TIMEZONE_CHANGES))
      end,
      # What a restore form would do, asked for as it is filled in.
      streak_preview: InertiaRails.optional { user_streak_preview }
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

  def include_deleted? = params[:include_deleted] == "1"

  def user_streak_preview
    fields = params.fetch(:preview, {})
    return streak_preview(build_streak_adjustment(fields, user: @user)) if fields[:undo].blank?

    streak_plan(@user.streak_adjustments.find_by_public_id!(fields[:undo]).undo_preview)
  end

  def user_params
    params.expect(user: [ :is_banned, roles: [] ])
  end
end
