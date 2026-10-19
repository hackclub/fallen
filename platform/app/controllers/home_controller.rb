class HomeController < ApplicationController
  allow_trial_access only: :index # Where the onboarding runs
  skip_after_action :verify_authorized # Shows only the current user's own data
  skip_after_action :verify_policy_scoped # Projects go through policy_scope, but only in the deferred request

  ACTIVITY_DAYS = 49

  # Nothing deferred: these are a dozen indexed queries over one person's own rows, about 15ms together, and a
  # deferred prop costs the browser another round trip to the server, 100-300ms for most people.
  def index
    render inertia: "Home/Index", props: { projects: projects, stats: stats, xp: xp, activity: activity }
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

  # Where the person stands: XP and form, their team's week so far (Lulu's start on their first journal), and the
  # race between the teams this Monday-to-Sunday week.
  def xp
    today = current_user.local_date
    team = current_user.team
    week = team ? team.week(today) : Week.of(today)
    {
      total: current_user.xp, form: current_user.pet_form, next_stage_xp: current_user.next_stage_xp, progress: current_user.stage_progress,
      team: team&.name, multiplier: current_user.xp_multiplier.to_f, freezes: current_user.streak_freezes,
      rules: Team.rules,
      week: {
        start: week.start.iso8601, today: today.iso8601,
        days: team ? team.journal_days(week).map(&:iso8601) : [],
        since: team&.first_journal_day&.iso8601,
        totals: XpEntry.team_totals(Week.of(today))
      }
    }
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
