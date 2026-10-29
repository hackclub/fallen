class ProjectsController < ApplicationController
  allow_trial_access only: %i[index show new create edit update destroy] # The onboarding makes a project
  include SlackStatus
  include LapseStatus
  include TeamProps

  JOURNALS_PER_PAGE = 20

  before_action :set_project, only: %i[show edit update destroy]

  def index
    projects = Project.preload_teams(policy_scope(Project).recent.with_attached_banner.to_a, known: [ current_user ])

    render inertia: "Projects/Index", props: {
      projects: ProjectSerializer.render(projects, **Project.journal_totals(projects), covers: Project.journal_covers(projects), viewer: current_user),
      invites: pending_invites,
      slack: slack_props,
      direct_upload_url: uploads_path,
      can: { create: policy(Project).create? }
    }
  end

  def show
    authorize @project
    Project.preload_teams([ @project ], known: [ current_user ])
    totals = Project.journal_totals([ @project ])
    pagy, journals = pagy(@project.journals.kept.newest_first.includes(:xp_entry, :lapse_timelapses, images_attachments: :blob), limit: JOURNALS_PER_PAGE, count: totals[:counts].fetch(@project.id, 0))
    # Their authors are nearly always on the team, which is loaded already.
    ActiveRecord::Associations::Preloader.new(records: journals.to_a, associations: :user, available_records: @project.teammates).call
    policy = policy(@project)

    render inertia: "Projects/Show", props: {
      project: ProjectSerializer.render(@project, covers: Project.journal_covers([ @project ]), **totals),
      journals: JournalSerializer.render(journals),
      team: team_props(@project, invite: policy.invite?),
      people: InertiaRails.optional { people_to_invite(@project, params[:people_query]) if policy.invite? },
      pagy: pagy_props(pagy),
      slack: slack_props,
      direct_upload_url: uploads_path,
      lapse: InertiaRails.defer { lapse_props(timelapses: true) if @project.on_team?(current_user) },
      writing_check: WritingCheck.mode_for(current_user),
      can: {
        update: policy.update?, destroy: policy.destroy?, journal: policy(@project.journals.build(user: current_user)).create?,
        invite: policy.invite?, leave: policy.leave?, remove_teammate: policy.remove_teammate?
      }
    }
  end

  def new
    authorize Project
    render inertia: "Projects/Form", props: { project: nil, direct_upload_url: uploads_path }
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
    Project.preload_teams([ @project ], known: [ current_user ])
    render inertia: "Projects/Form", props: { project: ProjectSerializer.render(@project), direct_upload_url: uploads_path }
  end

  def update
    authorize @project

    if @project.update(project_params)
      UpdateProjectOnSlackJob.perform_later(@project) if @project.saved_change_to_title? || @project.saved_change_to_description?
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
