class ProjectsController < ApplicationController
  allow_trial_access only: %i[index show new create edit update destroy] # The onboarding makes a project
  include SlackStatus
  include LapseStatus
  include TeamProps

  JOURNALS_PER_PAGE = 20
  JOURNAL_REVIEWS_SHOWN = 5

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
    policy = policy(@project)
    # Someone looking at another team's project sees the project and its journals, not its review or timelapses.
    insider = policy.show_private?
    preload = [ :xp_entry, *(:lapse_timelapses if insider), { images_attachments: :blob } ]
    pagy, journals = pagy(@project.journals.kept.newest_first.includes(*preload), limit: JOURNALS_PER_PAGE, count: totals[:counts].fetch(@project.id, 0))
    # Their authors are nearly always on the team, which is loaded already.
    ActiveRecord::Associations::Preloader.new(records: journals.to_a, associations: :user, available_records: @project.teammates).call
    submission = Submission.latest_for(@project) if insider
    ActiveRecord::Associations::Preloader.new(records: [ submission ], associations: [ :bom_items, :grant_payout, { screenshots_attachments: :blob } ]).call if submission
    can_submit = can_submit?(submission)

    render inertia: "Projects/Show", props: {
      project: ProjectSerializer.render(@project, covers: Project.journal_covers([ @project ]), **totals),
      journals: JournalSerializer.render(journals, timelapses: insider),
      team: team_props(@project, invite: policy.invite?),
      people: InertiaRails.optional { people_to_invite(@project, params[:people_query]) if policy.invite? },
      # Optional: only sent when someone opens "Move" on one of their journals here (Journal#move_to).
      move_targets: InertiaRails.optional { ProjectChoiceSerializer.render(move_targets) },
      pagy: pagy_props(pagy),
      slack: slack_props,
      direct_upload_url: uploads_path,
      lapse: InertiaRails.defer { lapse_props(timelapses: true) if @project.on_team?(current_user) },
      writing_check: WritingCheck.mode_for(current_user),
      submission: submission && SubmissionSerializer.render(submission),
      # The submit popup first asks for their address through Hack Club Auth (User#needs_hca_address?).
      submit_needs_address: can_submit && current_user.needs_hca_address?,
      # Journal review (ProgressReview): what reviewers said, what's left to fix, XP held back, and asking for one.
      journal_review: InertiaRails.defer { journal_review_props(@project) if insider },
      can: {
        submit: can_submit, withdraw: submission.present? && policy(submission).destroy?,
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

  def journal_review_props(project)
    teammate = project.on_team?(current_user)
    blocker = teammate ? ProgressStatus.request_blocker(project) : nil
    {
      reviews: ProgressReviewSerializer.render(project.progress_reviews.reviews.newest_first.limit(JOURNAL_REVIEWS_SHOWN)),
      # Why the team can't ask for a review right now (nil if they can); not shown to anyone else.
      request_blocker: blocker,
      can_request: teammate && blocker.nil?
    }
  end

  # Whether the project can go for design review now: on the team, the flag on, and nothing waiting or decided for good.
  def can_submit?(latest)
    Flipper.enabled?(SubmissionsController::FLAG, current_user) && policy(Submission.new(project: @project)).create? &&
      (latest.nil? || latest.returned?)
  end

  def move_targets
    return [] if @project.approved?

    Project.kept.teamed_with(current_user).where(approved_at: nil).where.not(id: @project.id).order(:title)
  end

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
