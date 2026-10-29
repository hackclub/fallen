# frozen_string_literal: true

# Judges someone's streak again after days are excused, or an excuse is undone (StreakAdjustment). Team Sami's weeks
# (StreakWeek) are replayed in order from the state the first started with: a week holding a `changed` day is judged
# again from today's journals, the others keep the days they were judged on, and each hands what it left to the next.
# What happened between two weeks stays: freezes granted or taken as a difference, a multiplier set by a pet switch or
# an admin as it was. With `reprice`, journals saved at a multiplier that changed are worth the new one. Team Lulu's
# bonus is paid, or taken back, for each ended week holding a changed day since the person joined Lulu. Both count
# only days on the team: a Sami week from the day of a switch to Sami in it, Lulu's from the switch to Lulu.
class StreakReplay
  Change = Data.define(:week, :attributes) do
    def broken? = attributes[:freezes_before] < attributes[:missed]
  end

  Reprice = Data.define(:entry, :multiplier, :amount) do
    def xp = entry.discarded? ? 0 : amount - entry.amount
  end

  # Pays the week's bonus, or takes back `entry`.
  Bonus = Data.define(:week, :entry) do
    def pay? = entry.nil?
    def xp = pay? ? Team::Lulu::WEEKLY_BONUS : -entry.amount
  end

  # `multiplier` and `freezes` are [now, after]. `open_days` are changed days in weeks Sami hasn't judged yet, which
  # count when they close. `granted` is XP an admin gives outright (StreakAdjustment kind "xp").
  Plan = Data.define(:changes, :multiplier, :freezes, :reprices, :bonuses, :open_days, :granted) do
    def initialize(granted: 0, **fields) = super(granted:, **fields)

    def xp = reprices.sum(&:xp) + bonuses.sum(&:xp) + granted
    def restored = changes.count { it.week.broken? && !it.broken? }
    def broken = changes.count { !it.week.broken? && it.broken? }
    def changed? = changes.any? || multiplier.uniq.size > 1 || freezes.uniq.size > 1 || reprices.any? || bonuses.any? || granted.nonzero?

    def effect
      { "multiplier" => multiplier.map(&:to_f), "freezes" => freezes, "weeks" => changes.size, "restored" => restored, "broken" => broken,
        "journals" => reprices.size, "bonuses" => bonuses.sum { it.pay? ? 1 : -1 }, "xp" => xp }
    end
  end

  attr_reader :user, :changed, :excused, :reprice, :now

  def initialize(user, changed:, excused: StreakAdjustment.excused_days(user), reprice: true, now: Time.current)
    @user = user
    @changed = changed.to_set
    @excused = excused
    @reprice = reprice
    @now = now
  end

  def plan
    weeks = user.streak_weeks.order(:start).to_a
    changes = []
    windows = []
    state = nil
    weeks.each do |week|
      if state
        multiplier, freezes = carry(state, week.multiplier_before, week.freezes_before, until_time: week.created_at)
        windows << window(state, week.multiplier_before, until_time: week.created_at)
      else
        multiplier, freezes = week.multiplier_before, week.freezes_before
      end
      judged = judge(week, multiplier, freezes)
      attributes = { multiplier_before: multiplier, freezes_before: freezes, **judged.attributes }
      changes << Change.new(week, attributes) if attributes.any? { |key, value| week[key] != value }
      state = { old: [ week.multiplier, week.freezes ], new: [ judged.multiplier, judged.attributes[:freezes] ], at: week.created_at }
    end

    if state
      multiplier, freezes = carry(state, user.xp_multiplier, user.streak_freezes, until_time: now)
      windows << window(state, user.xp_multiplier, until_time: now)
    else
      multiplier, freezes = user.xp_multiplier, user.streak_freezes
    end
    multiplier = user.xp_multiplier unless user.pet == "sami"
    last_judged = weeks.last&.week&.finish
    open_days = user.pet == "sami" ? changed.select { last_judged.nil? || it > last_judged }.sort : []
    Plan.new(changes:, multiplier: [ user.xp_multiplier, multiplier ], freezes: [ user.streak_freezes, freezes ], reprices: reprices(windows.compact),
             bonuses: bonuses, open_days:)
  end

  # Judges again and writes the result, locked against the weekly close. Returns what changed (Plan#effect), or nil.
  def run!
    user.transaction do
      user.lock!
      plan = self.plan
      apply!(plan) if plan.changed?
    end
  end

  # Writes the plan and returns its effect, worked out before the writes change what it compares against.
  def apply!(plan)
    effect = plan.effect
    plan.changes.each { it.week.update!(it.attributes) }
    user.update!(xp_multiplier: plan.multiplier.last, streak_freezes: plan.freezes.last)
    plan.reprices.each { it.entry.update!(multiplier: it.multiplier, amount: it.entry.discarded? ? it.entry.amount : it.amount) }
    plan.bonuses.each do |bonus|
      next bonus.entry.discard if bonus.entry

      entry = user.xp_entries.find_or_initialize_by(kind: "weekly_bonus", day: bonus.week.finish, source_id: nil)
      entry.update!(amount: Team::Lulu::WEEKLY_BONUS, discarded_at: nil)
    end
    effect
  end

  # Moves between a week and what comes after it (the next week, or now) what the replay changed, keeping what
  # happened in between.
  def carry(state, multiplier, freezes, until_time:)
    between = boundaries.select { |time, _| time > state[:at] && time <= until_time }.map(&:last)
    return [ multiplier, freezes ] if between.include?(:set)

    kept = between.include?(:pet) || multiplier != state[:old].first
    [ kept ? multiplier : state[:new].first, [ state[:new].last + freezes - state[:old].last, 0 ].max ]
  end

  private

  def judge(week, multiplier, freezes)
    return StreakWeek.settle(multiplier:, freezes:, missed: week.missed, excused: week.excused) unless week.week.days.any? { changed.include?(it) }

    from = [ first_journal_day || week.start, week.start, joined_sami(week) ].compact.max
    StreakWeek.judge(multiplier:, freezes:, days: from..week.week.finish, journaled:, excused:)
  end

  # Journals saved after a week was judged, until the next week or a boundary, have the multiplier it left. None when
  # it didn't change, or changed some other way since with no boundary to say how.
  def window(state, multiplier, until_time:)
    old, new = state[:old].first, state[:new].first
    return if old == new

    to = [ until_time, *boundaries.filter_map { |time, _| time if time > state[:at] } ].min
    return if to == until_time && multiplier != old

    [ old, new, state[:at]...to ]
  end

  def reprices(windows)
    return [] if !reprice || windows.empty?

    entries = user.xp_entries.journals.where(created_at: windows.map { it.last.begin }.min..).to_a.filter_map do |entry|
      old, new, = windows.find { |old, _, range| range.cover?(entry.created_at) && entry.multiplier == old }
      [ entry, new ] if old
    end
    minutes = Journal.where(id: entries.map { it.first.source_id }).pluck(:id, :duration_minutes).to_h
    entries.filter_map do |entry, multiplier|
      Reprice.new(entry, multiplier, XpEntry.journal_xp(minutes[entry.source_id], multiplier)) if minutes[entry.source_id]
    end
  end

  def bonuses
    return [] unless user.pet == "lulu"

    team = user.team
    today = user.local_date(now)
    joined = user.pet_switched_at && user.local_date(user.pet_switched_at)
    paid = user.xp_entries.kept.where(kind: "weekly_bonus").to_a
    weeks = changed.map { team.week(it) }.uniq.select { it.finish < today && (joined.nil? || it.finish >= joined) }
    weeks.filter_map do |week|
      days = week.days.count { (joined.nil? || it >= joined) && (journaled.include?(it) || excused.include?(it)) }
      entry = paid.find { it.day.between?(week.start, week.finish + 6) }
      if days >= Team::Lulu::DAYS_FOR_BONUS && entry.nil?
        Bonus.new(week, nil)
      elsif days < Team::Lulu::DAYS_FOR_BONUS && entry&.day == week.finish
        Bonus.new(week, entry)
      end
    end
  end

  def journaled = @journaled ||= user.xp_entries.kept.journals.distinct.pluck(:day).to_set
  def first_journal_day = journaled.min

  # The day in the week the person switched to Sami, if they did.
  def joined_sami(week) = switches.filter_map { |time, pet| user.local_date(time) if pet == "sami" }.select { week.week.days.cover?(it) }.max

  # Pet switches from the user's history: when, and to which pet.
  def switches
    @switches ||= PaperTrail::Version.where(item_type: "User", item_id: user.id).where("object_changes ? 'pet_switched_at'")
      .pluck(:created_at, Arel.sql("object_changes -> 'pet' ->> 1"))
  end

  # When the multiplier was set some other way than a week closing: pet switches and admins setting it, or undoing
  # that.
  def boundaries
    @boundaries ||= [
      *switches.map { [ it.first, :pet ] },
      *user.streak_adjustments.where(kind: "set").pluck(:created_at, :discarded_at).flatten.compact.map { [ it, :set ] }
    ].sort_by(&:first)
  end
end
