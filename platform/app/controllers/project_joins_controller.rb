# A project's join link (Project#join_token): anyone signed in can see whose project it is and join the team.
class ProjectJoinsController < ApplicationController
  allow_unauthenticated_access only: :show # Someone sent the link may not have an account yet
  allow_trial_access only: :show # Joining needs Hack Club Auth, which the page asks for
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized
  before_action :set_project

  def show
    authorize @project, :show_invitation?
    return redirect_to project_path(@project) if @project.on_team?(current_user)

    Project.preload_teams([ @project ])

    remember_return_to(request.fullpath) unless current_user && !current_user.trial?

    render inertia: "ProjectJoins/Show", props: {
      project: ProjectSerializer.render(@project, **Project.journal_totals([ @project ]), covers: Project.journal_covers([ @project ])),
      token: params[:token],
      full: @project.team_full?,
      signed_in: current_user.present? && !current_user.trial?
    }
  end

  def create
    authorize @project, :join?
    member = @project.memberships.build(user: current_user)

    if member.save
      current_user.project_invites.where(project: @project).delete_all
      TeammateJoinedJob.perform_later(@project, current_user)
      redirect_to project_path(@project), notice: "You're on the team for #{@project.title}!"
    else
      redirect_to join_path(params[:token]), alert: member.errors.full_messages.first
    end
  end

  private

  def set_project
    @project = Project.kept.find_by!(join_token: params[:token].to_s)
  end
end
