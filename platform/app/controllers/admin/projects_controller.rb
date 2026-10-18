class Admin::ProjectsController < Admin::ApplicationController
  def index
    scope = policy_scope([ :admin, Project ]).includes(:user).with_attached_banner
    scope = scope.kept unless include_deleted?
    scope = search(scope, params[:query]) if params[:query].present?

    render inertia: "Admin/Projects/Index", props: {
      query: params[:query].to_s,
      include_deleted: include_deleted?,
      total_count: InertiaRails.defer(group: "table") { scope.count },
      **deferred_table(scope.order(updated_at: :desc), AdminProjectSerializer, :projects) { |projects| Project.journal_totals(projects) }
    }
  end

  def show
    project = Project.find_by_public_id!(params[:id])
    authorize [ :admin, project ]

    journals = project.journals.kept
    pagy, page = pagy(journals.newest_first.includes(:xp_entry, :lapse_timelapses, images_attachments: :blob))

    render inertia: "Admin/Projects/Show", props: {
      project: AdminProjectSerializer.render(project),
      missing_hours: journals.needing_hours.count,
      journals: AdminJournalSerializer.render(page),
      pagy: pagy_props(pagy),
      can: { update: policy([ :admin, project ]).update? }
    }
  end

  def update
    project = Project.find_by_public_id!(params[:id])
    authorize [ :admin, project ]
    project.update!(params.expect(project: [ :approved ]))
    redirect_to admin_project_path(project), notice: project.approved? ? "Project approved." : "Approval removed."
  end

  private

  def include_deleted? = params[:include_deleted] == "1"

  def search(scope, query)
    pattern = "%#{Project.sanitize_sql_like(query)}%"
    scope.joins(:user).where("projects.title ILIKE :q OR users.display_name ILIKE :q OR users.email ILIKE :q", q: pattern)
  end
end
