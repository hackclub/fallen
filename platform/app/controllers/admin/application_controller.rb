class Admin::ApplicationController < ApplicationController
  before_action :require_admin!

  # Sidebar count pills. Deferred so they never hold up a page.
  inertia_share do
    { admin_stats: InertiaRails.defer { Admin::ApplicationController.sidebar_counts } }
  end

  def self.sidebar_counts
    { users_count: User.kept.count, projects_count: Project.kept.count }
  end

  private

  # A paginated table as deferred props: `key` (rows) and `pagy`, fetched together after the page shell renders.
  # The block can return extra serializer params for the loaded page of records.
  def deferred_table(scope, serializer, key, &serializer_params)
    page = -> { @deferred_page ||= pagy(scope).then { |pagy, records| [ pagy, records.to_a ] } }

    {
      key => InertiaRails.defer(group: "table") do
        records = page.call.last
        serializer.render(records, **(serializer_params&.call(records) || {}))
      end,
      pagy: InertiaRails.defer(group: "table") { pagy_props(page.call.first) }
    }
  end

  def project_totals(projects)
    journals = Journal.kept.where(project_id: projects.map(&:id)).group(:project_id)
    { totals: journals.sum(:duration_minutes), counts: journals.count }
  end

  def require_admin!
    raise ActionController::RoutingError, "Not Found" unless current_user&.admin?
  end
end
