# frozen_string_literal: true

# A week of the team race as /admin/teams shows it: each team's XP, the people and projects on each that earned the
# most, and whether the win is paid. An admin pays it once the week is over (TeamWinJob). Transfers never count
# towards winning (XpEntry.during); with `transfers:` the people, projects and charts count them anyway, on the day
# they were approved, with the hours their reviewer approved.
class TeamRace
  TOP = 10
  CHART_POINTS = 500
  # The project and hours behind an entry from `sourced`: a journal's, or a transfer's.
  PROJECT = "COALESCE(journals.project_id, project_transfers.project_id)"
  MINUTES = "COALESCE(journals.duration_minutes, project_transfers.approved_minutes, 0)"

  attr_reader :week, :transfers

  # Fallen's weeks so far, oldest first: week 1 is the one its first journal was written in.
  def self.weeks
    first = Journal.written_here.minimum(:created_at)&.to_date || Date.current
    (Week.of(first).start..Week.of(Date.current).start).step(7).map { Week.new(start: it) }
  end

  # Each week's XP by team, its transferred XP apart, and whether its win was paid, for the week tabs and the overall
  # totals. One grouped query over every week, so the weeks never cost a query each.
  def self.history(weeks = self.weeks)
    xp = XpEntry.raced(transfers: true).joins(:user).where.not(users: { pet: nil })
      .group(Arel.sql("date_trunc('week', xp_entries.day)::date"), "users.pet", Arel.sql("xp_entries.kind = 'transfer'"))
      .sum(:amount)
    paid = XpEntry.where(kind: "team_win").distinct.pluck(:day).to_set

    weeks.map do |week|
      { start: week.start.iso8601, xp: User::PETS.to_h { [ it, xp[[ week.start, it, false ]].to_i ] },
        transferred: User::PETS.to_h { [ it, xp[[ week.start, it, true ]].to_i ] }, paid: paid.include?(week.finish) }
    end
  end

  # Every week's XP so far as running totals by team, in at most CHART_POINTS steps of whole hours.
  def self.overall_timeline(weeks = self.weeks, transfers: false)
    from = weeks.first.start.in_time_zone
    step = [ ((Time.current - from) / CHART_POINTS / 1.hour).ceil, 1 ].max.hours
    running(XpEntry.raced(transfers:), from, Time.current, step)
  end

  # [{ at:, lulu:, sami: }] every `step` from `from` to `to`: each team's XP logged up to then. XP logged before `from`
  # (a person ahead of UTC starting their Monday early) counts from the first point.
  def self.running(scope, from, to, step)
    bucket = XpEntry.sanitize_sql_array([ "floor(extract(epoch from xp_entries.created_at) / ?)", step.to_i ])
    xp = scope.joins(:user).where.not(users: { pet: nil }).group(Arel.sql(bucket), "users.pet").sum(:amount)
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

  def current? = week == Week.of(Date.current)
  def paid? = XpEntry.exists?(kind: "team_win", day: week.finish)
  def payable? = week.over? && !paid?

  # Each team's XP (XpEntry.team_totals), its transferred XP apart, how many on it earned some (and so would be paid if
  # it wins), and how many were paid, by pet name.
  def teams
    xp = XpEntry.during(week, transfers: true).joins(:user).where.not(users: { pet: nil })
      .group("users.pet", Arel.sql("xp_entries.kind = 'transfer'")).sum(:amount)
    earners = XpEntry.during(week).where("amount > 0").where(user_id: User.on_a_team.select(:id)).joins(:user)
      .group("users.pet").distinct.count(:user_id)
    paid = XpEntry.where(kind: "team_win", day: week.finish).joins(:user).group("users.pet").count
    User::PETS.map do |pet|
      { pet: pet, xp: xp[[ pet, false ]].to_i, transferred: xp[[ pet, true ]].to_i, contributors: earners[pet].to_i, paid: paid[pet].to_i }
    end
  end

  # The week's XP as running totals by team, an hour at a time up to now or until Sunday has ended everywhere, so its
  # chart has a number wherever the cursor is.
  def timeline
    self.class.running(earned, week.start.in_time_zone, [ Time.current, week.ends_at ].min, 1.hour)
  end

  # The TOP people on each team who earned the most XP in the week, with their hours.
  def leaders = people(top_per_team(earned, "xp_entries.user_id"))

  # Everyone on the team who earned XP in the week, most first, to page through: rows of user_id and xp.
  def contributors(pet)
    earned.joins(:user).merge(User.on_a_team).where(users: { pet: pet }).group(:user_id)
      .select(:user_id, "SUM(xp_entries.amount) AS xp").order(Arel.sql("SUM(xp_entries.amount) DESC"), :user_id)
  end

  # [user_id, pet, xp] rows as the people they are, with the hours behind their XP in the week.
  def people(rows)
    ids = rows.map(&:first)
    minutes = sourced.where(user_id: ids).group("xp_entries.user_id").sum(Arel.sql(MINUTES))
    users = User.where(id: ids).index_by(&:id)

    rows.map { |id, pet, xp| { user: users[id], pet: pet, xp: xp, minutes: minutes[id].to_i } }
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

  def earned = XpEntry.during(week, transfers:)

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
    ranked = scope.joins(:user).merge(User.on_a_team).group(key, "users.pet").select(
      "#{key} AS key", "users.pet AS pet", "SUM(xp_entries.amount) AS xp", *extra.map { |name, sql| "#{sql} AS #{name}" },
      "ROW_NUMBER() OVER (PARTITION BY users.pet ORDER BY SUM(xp_entries.amount) DESC, #{key}) AS rank"
    )
    scope.klass.unscoped.from(ranked, :ranked).where("ranked.rank <= ?", TOP).order("ranked.pet", "ranked.rank")
      .pluck(:key, :pet, :xp, *extra.keys)
  end
end
