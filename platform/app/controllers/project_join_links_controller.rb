# Turning a project's join link into a new one, so the old one stops working.
class ProjectJoinLinksController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized

  def create
    project = Project.kept.find_by_public_id!(params[:project_id])
    authorize project, :invite?
    project.regenerate_join_token
    redirect_to project_path(project), notice: "New link made. The old one no longer works."
  end
end
