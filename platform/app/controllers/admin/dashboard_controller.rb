class Admin::DashboardController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # Aggregate counts only, no records are exposed

  def index
    render inertia: "Admin/Dashboard/Index", props: {
      stats: {
        users: User.kept.count,
        admins: User.kept.admins.count,
        banned: User.kept.banned.count,
        seen_today: User.kept.where(last_seen_at: Time.current.all_day).count
      },
      slack_configured: SlackBot.configured?
    }
  end
end
