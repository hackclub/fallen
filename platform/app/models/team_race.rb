# frozen_string_literal: true

# A week of the team race as /admin/teams shows it: each team's XP, the people and projects on each that earned the
# most, and whether the win is paid. The race's weeks are the same instants for everyone (Week#race_times), and XP
# counts for the team it was made on (XpEntry#pet), from people who can be paid (User.on_a_team). An admin pays the
# win once the week is over (TeamWinJob). Transfers never count towards winning (XpEntry.raced_in); with
# `transfers:` the people, projects and charts count them anyway, when they were approved, with the hours their
# reviewer approved.
class TeamRace
  # The race's first Monday. XP from before it (testing before Fallen opened) stays in people's totals but isn't part
  # of the race.
  START = Date.new(2026, 10, 19)
  # The race's last day, the program's deadline: the last week ends early, when this day has ended everywhere.
  FINISH = DailyGoal::DEADLINE.to_date
  TOP = 10
  CHART_POINTS = 500
  # The project and hours behind an entry from `sourced`: a journal's, or a transfer's.
  PROJECT = "COALESCE(journals.project_id, project_transfers.project_id)"
  MINUTES = "COALESCE(journals.duration_minutes, project_transfers.approved_minutes, 0)"

  attr_reader :week, :transfers

  # The race's day and week of each entry, in SQL: in Week::RACE_ZONE, so weeks run Monday to Sunday anywhere on
  # Earth. created_at is UTC.
  DAY = "((xp_entries.created_at AT TIME ZONE 'UTC') AT TIME ZONE '#{Week::RACE_ZONE}')::date"
  WEEK = "date_trunc('week', #{DAY})::date"

  # The race's weeks so far, Monday to Sunday, oldest first, from START.
  def self.weeks = (START..[ Week.racing.start, START ].max).step(7).map { Week.new(start: it) }

  # Each week's XP by team, its transferred XP apart, and which teams its win was paid to, for the week tabs and the
  # overall totals. One grouped query over every week, so the weeks never cost a query each.
  def self.history(weeks = self.weeks)
    xp = teamed(XpEntry.raced(transfers: true).where(created_at: weeks.first.starts_at...weeks.last.ends_at))
      .group(Arel.sql(WEEK), "xp_entries.pet", Arel.sql("xp_entries.kind = 'transfer'")).sum(:amount)
    paid = XpEntry.where(kind: "team_win").distinct.pluck(:day, :pet).group_by(&:first).transform_values { it.map(&:last).compact.sort }

    weeks.map do |week|
      { start: week.start.iso8601, xp: User::PETS.to_h { [ it, xp[[ week.start, it, false ]].to_i ] },
        transferred: User::PETS.to_h { [ it, xp[[ week.start, it, true ]].to_i ] }, paid: paid.key?(week.race_finish),
        paid_to: paid.fetch(week.race_finish, []) }
    end
  end

  # Every week's XP so far as running totals by team, in at most CHART_POINTS steps of whole hours.
  def self.overall_timeline(weeks = self.weeks, transfers: false)
    from = weeks.first.starts_at
    step = [ ((Time.current - from) / CHART_POINTS / 1.hour).ceil, 1 ].max.hours
    running(XpEntry.raced(transfers:).where(created_at: from..), from, Time.current, step)
  end

  # [{ at:, lulu:, sami: }] every `step` from `from` to `to`: each team's XP logged up to then.
  def self.running(scope, from, to, step)
    bucket = XpEntry.sanitize_sql_array([ "floor(extract(epoch from xp_entries.created_at) / ?)", step.to_i ])
    xp = teamed(scope).group(Arel.sql(bucket), "xp_entries.pet").sum(:amount)
      .group_by { |(index, _), _| Time.zone.at(index.to_i * step.to_i) }.sort_by(&:first)
    totals = User::PETS.index_with(0)

    (from.to_i..to.to_i).step(step.to_i).map do |seconds|
      at = Time.zone.at(seconds)
      while xp.any? && xp.first.first <= at
        xp.shift.last.each { |(_, pet), amount| totals[pet] += amount }
      end
      { at: at.iso8601, **totals }
    end
  end

  def initialize(week, transfers: false)
    @week = week
    @transfers = transfers
  end

  # Entries with a team, from people who can be paid.
  def self.teamed(scope) = scope.joins(:user).merge(User.on_a_team).where.not(pet: nil)

  def current? = week == Week.racing
  def paid? = XpEntry.exists?(kind: "team_win", day: week.race_finish)
  def payable? = week.over? && !paid?

  # Each team's XP (XpEntry.team_totals), its transferred XP apart, how many would be paid if it wins
  # (Team.contributors), and how many were paid, by pet name.
  def teams
    xp = self.class.teamed(XpEntry.raced_in(week, transfers: true)).group("xp_entries.pet", Arel.sql("xp_entries.kind = 'transfer'")).sum(:amount)
    earners = Team.contributors(week, User::PETS).group(:pet).count
    paid = XpEntry.where(kind: "team_win", day: week.race_finish).group(:pet).count
    User::PETS.map do |pet|
      { pet: pet, xp: xp[[ pet, false ]].to_i, transferred: xp[[ pet, true ]].to_i, contributors: earners[pet].to_i, paid: paid[pet].to_i }
    end
  end

  # The week's XP as running totals by team, an hour at a time up to now or until Sunday has ended everywhere, so its
  # chart has a number wherever the cursor is.
  def timeline
    self.class.running(earned, week.starts_at, [ Time.current, week.ends_at ].min, 1.hour)
  end

  # The TOP people on each team who earned the most XP in the week, with their hours.
  def leaders = people(top_per_team(earned, "xp_entries.user_id"))

  # Everyone on the team who earned XP in the week, most first, to page through: rows of user_id and xp.
  def contributors(pet)
    self.class.teamed(earned).where(pet: pet).group(:user_id)
      .select(:user_id, "SUM(xp_entries.amount) AS xp").order(Arel.sql("SUM(xp_entries.amount) DESC"), :user_id)
  end

  # [user_id, pet, xp] rows as the people they are, with the hours behind their XP for that team in the week, and
  # their days (#days).
  def people(rows)
    ids = rows.map(&:first)
    minutes = sourced.where(user_id: ids).group("xp_entries.user_id", "xp_entries.pet").sum(Arel.sql(MINUTES))
    users = User.where(id: ids).index_by(&:id)
    days = days(users.values)

    rows.map { |id, pet, xp| { user: users[id], pet: pet, xp: xp, minutes: minutes[[ id, pet ]].to_i, days: days[id] } }
  end

  # Each person's days of the race's week so far, by id: the teams they were on in each day (two on the day they
  # switched, in the order they were on them), from their pet changes, and the teams they earned XP for in it. Two
  # queries, whoever they are.
  def days(users)
    switches = PaperTrail::Version.where(item_type: "User", item_id: users.map(&:id)).where("object_changes ? 'pet'").order(:created_at, :id)
      .pluck(:item_id, :created_at, Arel.sql("object_changes -> 'pet' ->> 0"), Arel.sql("object_changes -> 'pet' ->> 1")).group_by(&:first)
    earned_on = earned.where(user_id: users.map(&:id)).where("xp_entries.amount > 0").distinct.pluck(:user_id, Arel.sql(DAY), :pet)
      .group_by { it.first(2) }.transform_values { it.map(&:last) }
    today = Time.current.in_time_zone(Week::RACE_ZONE).to_date

    users.to_h do |user|
      changes = switches.fetch(user.id, [])
      pet_at = ->(time) { changes.reverse.find { it[1] <= time }&.last || changes.first&.then { it[2] || it[3] } || user.pet }
      [ user.id, (week.start..[ week.race_finish, today ].min).map do |day|
        from = day.in_time_zone(Week::RACE_ZONE)
        on = [ pet_at.(from), *changes.filter_map { it.last if it[1] > from && it[1] < from + 1.day } ].compact.uniq
        earned_for = earned_on.fetch([ user.id, day ], [])
        { date: day.iso8601, on: on | earned_for, earned: earned_for.sort }
      end ]
    end
  end

  # The TOP projects on each team by the XP earned on them in the week. A project with people from both teams shows on
  # each, with what that team's people earned on it. XP with no project to point to (a transfer entry made by hand,
  # without its transfer) still counts for its person and team, just on no project.
  def projects
    rows = top_per_team(sourced.where("#{PROJECT} IS NOT NULL"), PROJECT, minutes: "SUM(#{MINUTES})", people: "COUNT(DISTINCT xp_entries.user_id)")
    projects = Project.where(id: rows.map(&:first)).select(:id, :title).index_by(&:id)

    rows.map do |id, pet, xp, minutes, people|
      project = projects.fetch(id)
      { id: project.public_id, title: project.title, pet: pet, xp: xp, minutes: minutes, people: people }
    end
  end

  private

  def earned = XpEntry.raced_in(week, transfers:)

  # The week's XP that came from a project, with the journal or transfer behind it: journals' entries (a deleted
  # journal's entry is discarded with it), and transfers' when they count.
  def sourced
    earned.where(kind: transfers ? %w[journal transfer] : "journal")
      .joins("LEFT JOIN journals ON xp_entries.source_type = 'Journal' AND journals.id = xp_entries.source_id")
      .joins("LEFT JOIN project_transfers ON xp_entries.source_type = 'ProjectTransfer' AND project_transfers.id = xp_entries.source_id")
  end

  # [key, pet, xp, *extra] for the TOP keys on each team by XP, one query: ranks each team's rows with a window. `key`
  # and `extra`'s SQL are this class's own, never input.
  def top_per_team(scope, key, **extra)
    ranked = self.class.teamed(scope).group(key, "xp_entries.pet").select(
      "#{key} AS key", "xp_entries.pet AS pet", "SUM(xp_entries.amount) AS xp", *extra.map { |name, sql| "#{sql} AS #{name}" },
      "ROW_NUMBER() OVER (PARTITION BY xp_entries.pet ORDER BY SUM(xp_entries.amount) DESC, #{key}) AS rank"
    )
    scope.klass.unscoped.from(ranked, :ranked).where("ranked.rank <= ?", TOP).order("ranked.pet", "ranked.rank")
      .pluck(:key, :pet, :xp, *extra.keys)
  end
end
