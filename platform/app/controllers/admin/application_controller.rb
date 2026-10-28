class Admin::ApplicationController < ApplicationController
  before_action :require_admin!

  # Sidebar count pills. Deferred so they never hold up a page.
  inertia_share do
    { admin_stats: InertiaRails.defer { Admin::ApplicationController.sidebar_counts } }
  end

  def self.sidebar_counts
    { users_count: User.kept.count, projects_count: Project.kept.count, failed_jobs_count: SolidQueue::FailedExecution.count }
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

  # A StreakAdjustment from a restore form's fields (StreakAdjustment::FIELDS), made by the admin at the keyboard.
  def build_streak_adjustment(fields, user:)
    StreakAdjustment.new(**fields.permit(*StreakAdjustment::FIELDS).to_h.symbolize_keys, user:, admin: true_user)
  end

  # What a restore form would do, for its preview: { errors:, plan: }. Nothing is saved.
  def streak_preview(adjustment)
    adjustment.reason = "preview" if adjustment.reason.blank?
    return { errors: adjustment.errors.full_messages, plan: nil } unless adjustment.valid?

    streak_plan(adjustment.preview)
  end

  def streak_plan(result)
    result.is_a?(String) ? { errors: [ result ], plan: nil } : { errors: [], plan: result && AdminStreakPreviewSerializer.render(result) }
  end

  def require_admin!
    raise ActionController::RoutingError, "Not Found" unless current_user&.admin?
  end
end
