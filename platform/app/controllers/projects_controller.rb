class ProjectsController < ApplicationController
  JOURNALS_PER_PAGE = 20

  before_action :set_project, only: %i[show edit update destroy]

  def index
    projects = policy_scope(Project).recent.to_a
    ids = projects.map(&:id)
    kept = Journal.kept.where(project_id: ids).group(:project_id)

    render inertia: "Projects/Index", props: {
      projects: ProjectSerializer.render(projects, totals: kept.sum(:duration_minutes), counts: kept.count),
      slack: slack_props,
      can: { create: policy(Project).create? }
    }
  end

  def show
    authorize @project
    pagy, journals = pagy(@project.journals.kept.newest_first.includes(images_attachments: :blob), limit: JOURNALS_PER_PAGE)

    render inertia: "Projects/Show", props: {
      project: ProjectSerializer.render(@project),
      journals: JournalSerializer.render(journals),
      pagy: pagy_props(pagy),
      slack: slack_props,
      direct_upload_url: rails_direct_uploads_path,
      can: { update: policy(@project).update?, destroy: policy(@project).destroy?, journal: policy(@project.journals.build(user: current_user)).create? }
    }
  end

  def new
    authorize Project
    render inertia: "Projects/Form", props: { project: nil }
  end

  def create
    project = current_user.projects.build(project_params)
    authorize project

    if project.save
      PostProjectToSlackJob.perform_later(project)
      redirect_to project_path(project), notice: "Project started."
    else
      inertia_errors(project, fallback_location: new_project_path)
    end
  end

  def edit
    authorize @project
    render inertia: "Projects/Form", props: { project: ProjectSerializer.render(@project) }
  end

  def update
    authorize @project

    if @project.update(project_params)
      redirect_to project_path(@project), notice: "Project updated."
    else
      inertia_errors(@project, fallback_location: edit_project_path(@project))
    end
  end

  def destroy
    authorize @project
    @project.discard
    redirect_to projects_path, notice: "Project deleted. Its Slack thread stays where it is."
  end

  private

  def set_project
    @project = Project.kept.find_by_public_id!(params[:id])
  end

  def project_params
    params.expect(project: %i[title description repo_url demo_url])
  end

  def slack_props
    {
      configured: SlackMessaging.configured?,
      oauth_available: SlackMessaging.oauth_configured?,
      connected: current_user.slack_connected?,
      linked: current_user.slack_id.present?
    }
  end
end
