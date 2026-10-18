class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  include SentryContext
  include Pagy::Method
  include InertiaHelpers

  before_action :set_paper_trail_whodunnit
  before_action :sync_browser_timezone

  # Fail closed: every action must call authorize (or skip_authorization), every index must policy_scope.
  # Controllers without an index action skip verify_policy_scoped blanket-style.
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  inertia_share do
    {
      auth: { user: current_user && UserSerializer.render(current_user) },
      impersonation: impersonating? ? { impersonator_name: true_user.display_name } : nil,
      setup: setup_props,
      # So Settings can show its Lapse tab on the instant visit from the nav rail, before its own props arrive.
      lapse_configured: Lapse.configured?
    }
  end

  private

  # What someone has left to do before the rest of the site: the onboarding, which picking a pet finishes, then
  # connecting Slack. Where the onboarding resumes comes from here rather than the browser, so leaving halfway
  # (closing the tab, another device) picks up at the same place. Costs one query, and only while onboarding.
  # Never while impersonating: the admin would be picking a pet or linking Slack for someone else.
  def setup_props
    return if current_user.nil? || current_user.is_banned? || impersonating?

    if current_user.pet.nil?
      { step: "onboarding", project: current_user.projects.kept.order(:created_at).pick(:title) }
    elsif !current_user.slack_connected? && SlackMessaging.oauth_configured?
      { step: "slack" }
    end
  end

  # PaperTrail records the real admin while impersonating, not the impersonated user.
  def user_for_paper_trail = true_user&.id

  # The frontend sends the browser's IANA zone on every Inertia visit (app/frontend/entrypoints/inertia.ts).
  def sync_browser_timezone
    return unless current_user && !impersonating?

    zone = request.headers["X-Browser-Timezone"]
    return if zone.blank? || zone == current_user.timezone || ActiveSupport::TimeZone[zone].nil?

    current_user.update_column(:timezone, zone)
  end

  def user_not_authorized
    flash[:alert] = "You are not allowed to do that."
    redirect_back(fallback_location: root_path)
  end
end
