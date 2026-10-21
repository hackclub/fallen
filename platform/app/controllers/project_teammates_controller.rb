# Leaving a project's team, or its owner taking someone off. Their journals stay on the project and stay theirs.
class ProjectTeammatesController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized

  def destroy
    project = Project.preload_teams([ Project.kept.find_by_public_id!(params[:project_id]) ]).first
    person = project.teammates.find { |teammate| teammate.public_id == params[:id] } or raise ActiveRecord::RecordNotFound
    leaving = person == current_user
    authorize project, leaving ? :leave? : :remove_teammate?

    project.remove_teammate(person)
    if leaving
      redirect_to projects_path, notice: "You left #{project.title}. Your journals on it are still yours."
    else
      redirect_to project_path(project), notice: "#{person.display_name} is off the team. Their journals stay on the project."
    end
  end
end
