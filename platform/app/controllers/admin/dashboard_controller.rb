class Admin::DashboardController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # Aggregate counts only, no records are exposed

  CHART_DAYS = 30

  def index
    render inertia: "Admin/Dashboard/Index", props: {
      stats: InertiaRails.defer { self.class.stats },
      activity: InertiaRails.defer { activity_chart },
      slack_configured: SlackBot.configured?
    }
  end

  # Six table scans. Deferred so the dashboard shell never waits on them. Also the MCP's get_dashboard.
  def self.stats
    journals = Journal.kept
    {
      users: User.kept.count,
      projects: Project.kept.count,
      journals: journals.count,
      minutes_logged: journals.sum(:duration_minutes),
      journals_missing_hours: journals.needing_hours.count,
      seen_today: User.kept.where(last_seen_at: Time.current.all_day).count
    }
  end

  private

  # One point per day: minutes logged in journals and people who signed up, in the admin's timezone.
  def activity_chart
    Time.use_zone(current_user.timezone) do
      days = (CHART_DAYS - 1).days.ago.to_date..Date.current
      since = days.first.beginning_of_day
      minutes = Journal.kept.written_here.where(created_at: since..).pluck(:created_at, :duration_minutes)
        .each_with_object(Hash.new(0)) { |(at, mins), totals| totals[at.in_time_zone.to_date] += mins.to_i }
      signups = User.kept.where(created_at: since..).pluck(:created_at).map { |at| at.in_time_zone.to_date }.tally

      days.map { |day| { date: day.iso8601, minutes: minutes[day], signups: signups.fetch(day, 0) } }
    end
  end
end
