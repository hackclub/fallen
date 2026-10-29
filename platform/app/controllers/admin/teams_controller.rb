# Team stats: the weekly team race (TeamRace). Where each team stands, the people and projects on each that earned the
# most, and the button that pays the win once the week is over.
class Admin::TeamsController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; both actions authorize explicitly

  def show
    race = find_and_authorize
    week = race.week

    render inertia: "Admin/Teams/Show", props: {
      week: { start: week.start.iso8601, finish: week.finish.iso8601 },
      transfers: race.transfers,
      weeks: weeks.map { { start: it.start.iso8601, finish: it.finish.iso8601, over: it.over? } },
      current: race.current?,
      over: week.over?,
      paid: race.paid?,
      win_bonus: Team::WIN_BONUS,
      can: { pay: policy([ :admin, race ]).pay? },
      history: InertiaRails.defer(group: "overall") { TeamRace.history(weeks) },
      overall_timeline: InertiaRails.defer(group: "overall") { TeamRace.overall_timeline(weeks, transfers: race.transfers) },
      teams: InertiaRails.defer(group: "race") { race.teams },
      timeline: InertiaRails.defer(group: "race") { race.timeline },
      leaders: InertiaRails.defer(group: "race") { serialize_people(race.leaders) },
      projects: InertiaRails.defer(group: "race") { race.projects },
      # A team's whole list, a page at a time, asked for when an admin opens it.
      contributors: InertiaRails.optional { contributors(race) }
    }
  end

  def pay
    race = find_and_authorize
    TeamWinJob.perform_later(race.week.start)
    redirect_to admin_teams_path(week: race.week.start.iso8601, transfers: params[:transfers].presence), notice: "Paying the win for the #{race.week}. Reload in a moment."
  end

  private

  def contributors(race)
    pet = User::PETS.find { it == params[:team] } or return
    pagy, rows = pagy(race.contributors(pet))
    { team: pet, people: serialize_people(race.people(rows.map { [ it.user_id, pet, it.xp ] })), pagy: pagy_props(pagy) }
  end

  def weeks = @weeks ||= TeamRace.weeks

  def serialize_people(rows) = rows.map { |row| row.merge(user: AdminUserSerializer.render(row[:user])) }

  # Never a week after this one, nor before the race started.
  def find_and_authorize
    TeamRace.new(Week.of([ [ requested_day, Date.current ].min, TeamRace::START ].max), transfers: params[:transfers] == "1").tap { authorize [ :admin, it ] }
  end

  def requested_day
    Date.iso8601(params[:week].to_s)
  rescue Date::Error
    Date.current
  end
end
