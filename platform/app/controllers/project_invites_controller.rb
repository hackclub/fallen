# Inviting someone to a project's team by name, and their answer. The invite's page is where the Slack DM
# (ProjectInviteJob) sends them.
class ProjectInvitesController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized
  before_action :set_invite, only: %i[show accept destroy]

  def create
    project = Project.kept.find_by_public_id!(params[:project_id])
    authorize project, :invite?
    invitee = User.on_a_team.find_by_public_id!(params.expect(invite: [ :user_id ])[:user_id])
    invite = project.invites.build(user: invitee, inviter: current_user)

    if project.open_seats.positive? && invite.save
      ProjectInviteJob.perform_later(invite)
      redirect_to project_path(project), notice: "Invited #{invitee.display_name}. They'll get a Slack DM."
    else
      redirect_to project_path(project), alert: invite.errors.full_messages.first || "The team is full (#{Project::MAX_TEAM} people at most)."
    end
  end

  def show
    authorize @invite
    render inertia: "ProjectInvites/Show", props: {
      invite: ProjectInviteSerializer.render(@invite),
      full: @invite.project.team_full?
    }
  end

  def accept
    authorize @invite
    member = @invite.accept!

    if member.persisted?
      TeammateJoinedJob.perform_later(member.project, member.user)
      redirect_to project_path(member.project), notice: "You're on the team for #{member.project.title}!"
    else
      redirect_back fallback_location: home_path, alert: member.errors.full_messages.first
    end
  end

  # Declining, or the team taking an invite back.
  def destroy
    authorize @invite
    @invite.destroy!
    mine = @invite.user_id == current_user.id
    redirect_back fallback_location: mine ? home_path : project_path(@invite.project), notice: mine ? "Invite declined." : "Invite cancelled."
  end

  private

  def set_invite
    @invite = ProjectInvite.live.find_by_public_id!(params[:id])
  end
end
