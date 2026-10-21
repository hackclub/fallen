# frozen_string_literal: true

# The numbers on /admin/stats over a range of UTC days: who opened the site (ActiveDay) and who built, the time the
# pet's timer tracked for everyone (TrackedTime's rules, not cut at each person's last journal) next to the hours
# journals logged, how far the people who signed up in the range got, and what the AI-writing check (WritingCheck)
# caught. Each public method is one deferred prop.
class ProgramStats
  # Range => days, nil for since the first signup.
  RANGES = { "7d" => 7, "30d" => 30, "90d" => 90, "all" => nil }.freeze
  DEFAULT_RANGE = "30d"

  # Each step counts the people who got through it and every step before it.
  FUNNEL = [
    [ "signed_up", "Signed up", "TRUE" ],
    [ "visited", "Opened the site", "users.last_seen_at IS NOT NULL" ],
    [ "picked_pet", "Picked a pet", "users.pet IS NOT NULL" ],
    [ "signed_in", "Signed in with Hack Club Auth", "users.hca_id IS NOT NULL" ],
    [ "slack", "Connected or skipped Slack", "users.slack_user_token IS NOT NULL OR users.slack_skipped_at IS NOT NULL" ],
    [ "project", "Has a project", <<~SQL.squish ],
      EXISTS (SELECT 1 FROM projects WHERE projects.user_id = users.id AND projects.discarded_at IS NULL)
      OR EXISTS (SELECT 1 FROM project_members JOIN projects ON projects.id = project_members.project_id
                 WHERE project_members.user_id = users.id AND projects.discarded_at IS NULL)
    SQL
    [ "tracked", "Tracked time", <<~SQL.squish ],
      EXISTS (SELECT 1 FROM timer_sessions WHERE timer_sessions.user_id = users.id)
      OR EXISTS (SELECT 1 FROM huddle_sessions WHERE huddle_sessions.user_id = users.id AND huddle_sessions.mode IS DISTINCT FROM 'chilling')
    SQL
    [ "journaled", "Wrote a journal", "EXISTS (SELECT 1 FROM journals WHERE journals.user_id = users.id AND journals.discarded_at IS NULL)" ],
    [ "returned", "Journaled on two days", <<~SQL.squish ]
      (SELECT COUNT(DISTINCT journals.created_at::date) FROM journals WHERE journals.user_id = users.id AND journals.discarded_at IS NULL) >= 2
    SQL
  ].freeze
  FUNNEL_COUNTS = FUNNEL.each_index.map { |i| "COUNT(*) FILTER (WHERE #{FUNNEL[..i].map { |(*, sql)| "(#{sql})" }.join(" AND ")})" }.freeze

  WRITING_COUNTS = {
    checked: "status = 'done'",
    flagged: "status = 'done' AND fraction_ai >= #{WritingCheck::FLAG_AT}",
    posted_anyway: "status = 'done' AND fraction_ai >= #{WritingCheck::FLAG_AT} AND journal_id IS NOT NULL",
    insisted: "insisted",
    skipped: "status = 'skipped'",
    failed: "status = 'failed'",
    limited: "status = 'limited'"
  }.freeze
  # Pangram bills each request by the 100 words, rounded up; failed and unfinished ones may have been billed too.
  BILLED_HUNDREDS = "COALESCE(SUM(CEIL(#{WritingCheck::WORDS_SQL} / 100.0)) FILTER (WHERE billed AND status IN ('pending', 'done', 'failed')), 0)"

  attr_reader :range

  def initialize(range:, now: Time.current)
    @range = RANGES.key?(range) ? range : DEFAULT_RANGE
    @now = now
  end

  # People who opened the site in the last day, week and 30 days, whatever the range.
  def active
    spans = { day: 1.day, week: 7.days, month: 30.days }
    counts = User.kept.pick(*spans.values.map { Arel.sql(User.sanitize_sql_array([ "COUNT(*) FILTER (WHERE last_seen_at >= ?)", @now - it ])) })
    spans.keys.zip(counts).to_h
  end

  # One point per day, plus the range's totals. Builders are people who tracked time or wrote a journal that day.
  def daily
    tracked = Hash.new(0)
    builders = Hash.new { |hash, day| hash[day] = Set.new }
    tracked_stretches.each do |user_id, stretches|
      TrackedTime.union(stretches).each do |stretch|
        each_day(*stretch) do |day, seconds|
          tracked[day] += seconds
          builders[day] << user_id
        end
      end
    end

    logged = Hash.new(0)
    Journal.kept.where(created_at: from..).pluck(Arel.sql("created_at::date"), :user_id, :duration_minutes).each do |day, user_id, minutes|
      logged[day] += minutes.to_i
      builders[day] << user_id
    end

    visitors = ActiveDay.where(day: days).group(:day).count
    signups = User.kept.where(created_at: from..).group(Arel.sql("created_at::date")).count

    {
      days: days.map do |day|
        { date: day.iso8601, visitors: visitors.fetch(day, 0), builders: builders.fetch(day, []).size, tracked_minutes: (tracked[day] / 60).round,
          logged_minutes: logged[day], signups: signups.fetch(day, 0) }
      end,
      totals: {
        visitors: ActiveDay.where(day: days).distinct.count(:user_id), builders: builders.values.reduce(Set.new, :|).size,
        tracked_minutes: (tracked.values.sum / 60).round, logged_minutes: logged.values.sum, signups: signups.values.sum
      }
    }
  end

  def funnel
    counts = User.kept.where(is_banned: false, created_at: from..).pick(*FUNNEL_COUNTS.map { Arel.sql(it) })
    FUNNEL.zip(counts).map { |(key, label), count| { key:, label:, count: } }
  end

  # Checks a day and how many were flagged, plus the range's totals and what Pangram billed for them.
  def writing
    selects = WRITING_COUNTS.values.map { Arel.sql("COUNT(*) FILTER (WHERE #{it})") } << Arel.sql(BILLED_HUNDREDS)
    rows = WritingCheck.where(created_at: from..).group(Arel.sql("created_at::date")).pluck(Arel.sql("created_at::date"), *selects)
    by_day = rows.to_h { |day, *counts| [ day, WRITING_COUNTS.keys.zip(counts).to_h.merge(hundreds: counts.last.to_i) ] }
    totals = (WRITING_COUNTS.keys + [ :hundreds ]).index_with { |key| by_day.values.sum { it[key] } }

    {
      days: days.map { |day| { date: day.iso8601, checked: by_day.dig(day, :checked) || 0, flagged: by_day.dig(day, :flagged) || 0 } },
      totals: totals.except(:hundreds).merge(cost_cents: totals[:hundreds] * Pangram::CENTS_PER_100_WORDS)
    }
  end

  private

  def days
    @days ||= begin
      today = @now.utc.to_date
      first = RANGES[range] ? today - (RANGES[range] - 1) : User.minimum(:created_at)&.utc&.to_date || today
      first..today
    end
  end

  def from = days.first.in_time_zone("UTC")

  # Everyone's tracked time that touches the range, by user id, before overlaps are joined.
  def tracked_stretches
    sessions = ending_after(HuddleSession.counting.where.not(user_id: nil), :left_at).select(:user_id, :joined_at, :left_at, :deducted_seconds).group_by(&:user_id)
    pauses = ending_after(HuddlePause.all, :ended_at).select(:user_id, :started_at, :ended_at).group_by(&:user_id)
    timers = ending_after(TimerSession.all, :stopped_at).select(:user_id, :started_at, :stopped_at, :deducted_seconds).group_by(&:user_id)

    (sessions.keys | timers.keys).index_with do |user_id|
      TrackedTime.huddle_stretches(sessions.fetch(user_id, []), pauses.fetch(user_id, []), @now) + TrackedTime.timer_stretches(timers.fetch(user_id, []), @now)
    end
  end

  def ending_after(scope, column) = scope.where(column => nil).or(scope.where(column => from..))

  # Splits a stretch, cut to the range, at UTC midnights.
  def each_day(start, finish)
    start = [ start, from ].max
    finish = [ finish, @now ].min
    while start < finish
      upto = [ finish, start.utc.to_date.next_day.in_time_zone("UTC") ].min
      yield start.utc.to_date, upto - start
      start = upto
    end
  end
end
