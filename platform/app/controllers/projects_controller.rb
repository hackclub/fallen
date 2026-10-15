class ProjectsController < ApplicationController
  include SlackStatus

  JOURNALS_PER_PAGE = 20

  before_action :set_project, only: %i[show edit update destroy]

  def index
    projects = policy_scope(Project).recent.with_attached_banner.to_a

    render inertia: "Projects/Index", props: {
      projects: ProjectSerializer.render(projects, **Project.journal_totals(projects), covers: Project.journal_covers(projects)),
      slack: slack_props,
      direct_upload_url: rails_direct_uploads_path,
      can: { create: policy(Project).create? }
    }
  end

  def show
    authorize @project
    pagy, journals = pagy(@project.journals.kept.newest_first.includes(images_attachments: :blob), limit: JOURNALS_PER_PAGE)

    render inertia: "Projects/Show", props: {
      project: ProjectSerializer.render(@project, covers: Project.journal_covers([ @project ])),
      journals: JournalSerializer.render(journals),
      owner: { name: @project.user.display_name, avatar: @project.user.avatar_url },
      pagy: pagy_props(pagy),
      slack: slack_props,
      direct_upload_url: rails_direct_uploads_path,
      can: { update: policy(@project).update?, destroy: policy(@project).destroy?, journal: policy(@project.journals.build(user: current_user)).create? }
    }
  end

  def new
    authorize Project
    render inertia: "Projects/Form", props: { project: nil, direct_upload_url: rails_direct_uploads_path }
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
    render inertia: "Projects/Form", props: { project: ProjectSerializer.render(@project), direct_upload_url: rails_direct_uploads_path }
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

  # `banner` is a direct upload's signed blob id; blank removes it.
  def project_params
    params.expect(project: %i[title description repo_url demo_url banner]).tap do |permitted|
      permitted[:banner] = nil if permitted.key?(:banner) && permitted[:banner].blank?
    end
  end
end
