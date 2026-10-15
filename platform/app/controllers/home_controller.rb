class HomeController < ApplicationController
  include SlackStatus

  skip_after_action :verify_authorized # Shows only the current user's own data
  skip_after_action :verify_policy_scoped # Projects go through policy_scope, but only in the deferred request

  ACTIVITY_DAYS = 49

  def index
    render inertia: "Home/Index", props: {
      slack: slack_props,
      can: { create_project: policy(Project).create? },
      direct_upload_url: rails_direct_uploads_path,
      projects: InertiaRails.defer { projects },
      stats: InertiaRails.defer { stats },
      activity: InertiaRails.defer { activity }
    }
  end

  private

  def projects
    projects = policy_scope(Project).recent.with_attached_banner.to_a
    ProjectSerializer.render(projects, **Project.journal_totals(projects), covers: Project.journal_covers(projects))
  end

  def stats
    minutes, count, missing, last_at = current_user.journals.kept.pick(
      Arel.sql("COALESCE(SUM(duration_minutes), 0), COUNT(*), COUNT(*) FILTER (WHERE duration_minutes IS NULL), MAX(created_at)")
    )
    { minutes: minutes, journals: count, missing_hours: missing, last_journal_at: last_at }
  end

  # Minutes logged per day in the person's own timezone, oldest first.
  def activity
    Time.use_zone(current_user.timezone) do
      days = (ACTIVITY_DAYS - 1).days.ago.to_date..Date.current
      minutes = current_user.journals.kept.where(created_at: days.first.beginning_of_day..).pluck(:created_at, :duration_minutes)
        .each_with_object(Hash.new(0)) { |(at, mins), totals| totals[at.in_time_zone.to_date] += mins.to_i }

      days.map { |day| { date: day.iso8601, minutes: minutes[day] } }
    end
  end
end
