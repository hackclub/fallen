# frozen_string_literal: true

# Lulu or Sami. The pet picked in onboarding is also the team, and each team rewards a week of journaling its own
# way: Lulu pays a bonus for enough journal days in each week counted from the person's first journal, Sami raises
# the multiplier on every journal for each Monday-to-Sunday week without a gap, with a few freezes
# (users.streak_freezes) to cover missed days. A day an admin excused (StreakAdjustment) counts as journaled for both.
# Both count only days since the person joined the team. `Team.close_week` has Sami judge its members' calendar week
# (CloseWeekJob). `Team.settle` pays Lulu's weeks as each person's ends (SettleLuluWeeksJob). The team that made the
# most XP in the race's week (Week#race_times) gets WIN_BONUS for each person still on it who journaled for it that
# week, paid when an admin presses the button on /admin/teams (TeamRace, TeamWinJob).
class Team
  WIN_BONUS = 10

  BY_PET = { "lulu" => "Team::Lulu", "sami" => "Team::Sami" }.freeze

  def self.for(user) = (name = BY_PET[user.pet]) && name.constantize.new(user)

  # The numbers the frontend explains the teams with, so its copy follows the constants.
  def self.rules
    {
      lulu_days: Lulu::DAYS_FOR_BONUS, lulu_bonus: Lulu::WEEKLY_BONUS,
      sami_step: Sami::STEP, sami_max: Sami::MAX_MULTIPLIER, sami_freezes: User.column_defaults["streak_freezes"],
      win_bonus: WIN_BONUS, xp_per_hour: XpEntry::PER_HOUR
    }
  end

  def self.close_week(week)
    User.on_a_team.find_each { |user| user.team.close_week(week) }
  end

  def self.settle
    User.on_a_team.where(pet: "lulu").find_each { |user| user.team.settle }
  end

  # Once per week, all or nothing, and only once the week is over everywhere: XP that lands after the payout must not
  # hand a second team the win.
  def self.reward_winners(week)
    return if !week.over? || XpEntry.exists?(kind: "team_win", day: week.race_finish)

    totals = XpEntry.team_totals(week)
    best = totals.values.max.to_i
    return if best.zero?

    winners = totals.select { |_, xp| xp == best }.keys
    XpEntry.transaction do
      contributors(week, winners).find_each do |user|
        user.xp_entries.create_or_find_by!(kind: "team_win", day: week.race_finish) { |entry| entry.amount = WIN_BONUS }
      end
    end
  end

  # People still on one of `pets` who journaled for it in the race's week: XP from before a switch counts for the team
  # it was made on, but its win is for the people on that team.
  def self.contributors(week, pets)
    User.on_a_team.where(pet: pets).where(id: XpEntry.raced_in(week).journals.where("amount > 0").where("xp_entries.pet = users.pet").select(:user_id))
  end

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def name = self.class.name.demodulize.downcase

  # Journal XP on each day of the week that has some, on the person's calendar. Kept per week, as the home page asks
  # twice (DailyGoal).
  def journal_xp(week) = (@journal_xp ||= {})[week] ||= user.xp_entries.journals.during(week).group(:day).sum(:amount)

  # Days of the week with a journal.
  def journal_days(week) = journal_xp(week).keys.sort

  # Days of the week with a journal or an excuse since joining the team, which is what the teams' weekly rewards count.
  def streak_days(week) = (journal_days(week) | week.days.select { excused_days.include?(it) }).select { on_team?(it) }.sort

  # The day the person switched to this team, on their calendar; nil if it's the pet they first picked.
  def joined_on = user.pet_switched_at && user.local_date(user.pet_switched_at)

  def on_team?(day) = joined_on.nil? || day >= joined_on

  # The first day the streak counts: the first journal, or the switch to the team if that was later.
  def streak_since = (first = first_journal_day) && [ first, joined_on ].compact.max

  def excused_days = @excused_days ||= StreakAdjustment.excused_days(user)

  # The streak starts with the first journal.
  def first_journal_day = user.xp_entries.kept.journals.minimum(:day)

  # The week the person's team counts `day` in.
  def week(day) = Week.of(day)

  # Judges a Monday-to-Sunday week that has ended.
  def close_week(week) = nil

  # The multiplier on each of `days` if the team's reward pays out in full from now on (DailyGoal).
  def best_multipliers(days) = [ user.xp_multiplier ] * days.count

  # Bonus XP the team's reward could still pay during `days`.
  def best_bonus_xp(days) = 0

  class Lulu < Team
    DAYS_FOR_BONUS = 5
    WEEKLY_BONUS = 30

    # Seven days from the first journal, then the next seven, and so on. Before any journal, the week would start
    # today. Discarded journals still count as the first, so deleting one never shifts weeks already paid.
    def week(day)
      first = first_day_counted || day
      Week.new(start: first + (day - first).to_i / 7 * 7)
    end

    # A bonus for each week that can still reach DAYS_FOR_BONUS and is paid by the last day, the day after it ends.
    # Only this week can be out of reach already: the days left in it with the ones journaled before today. Excused
    # days are left out of this forecast, which runs on every home page; paying the bonus counts them.
    def best_bonus_xp(days)
      current = week(days.first)
      reachable = journal_days(current).count { |day| day < days.first && on_team?(day) } + (current.finish - days.first).to_i + 1 >= DAYS_FOR_BONUS
      weeks = Enumerator.produce(current) { |w| Week.new(start: w.start + 7) }.take_while { |w| w.finish < days.last }
      weeks.count { |w| w != current || reachable } * WEEKLY_BONUS
    end

    # Pays the last week that has ended on the person's calendar. Run daily; each week is checked seven times and
    # paid once.
    def settle(today = user.local_date)
      last = week(today - 7)
      pay_for(last) if last.finish < today
    end

    # Never twice for the same days, even if the weeks have moved since a bonus was paid: a bonus sits on the last day
    # of its week, so one from start to six days after finish covered some of these days.
    def pay_for(week)
      return if streak_days(week).size < DAYS_FOR_BONUS
      return if user.xp_entries.kept.where(kind: "weekly_bonus", day: week.start..week.finish + 6).exists?

      user.xp_entries.create_or_find_by!(kind: "weekly_bonus", day: week.finish) { |entry| entry.amount = WEEKLY_BONUS }
    end

    private

    def first_day_counted
      return @first_day_counted if defined?(@first_day_counted)

      @first_day_counted = user.xp_entries.journals.minimum(:day)
    end
  end

  class Sami < Team
    STEP = 0.15
    MAX_MULTIPLIER = 1.75

    # Every multiplier a streak can reach, 1 then up STEP at a time.
    def self.multipliers = (0..((MAX_MULTIPLIER - 1) / STEP).round).map { (1 + it * STEP.to_d).round(2) }

    # Up STEP every Monday, when the week before is closed, to MAX_MULTIPLIER.
    def best_multipliers(days)
      days.map { |day| [ user.xp_multiplier + STEP * ((day.beginning_of_week - days.first.beginning_of_week).to_i / 7), MAX_MULTIPLIER ].min }
    end

    # Writes the week's StreakWeek and the multiplier and freezes it leaves, once. Locked against StreakAdjustment
    # changing them at the same time. Days count from the first journal or the switch to Sami, whichever is later, so a
    # week that ended before either isn't judged and raises nothing.
    def close_week(week)
      first = streak_since
      return if first.nil? || first > week.finish

      user.transaction do
        user.lock!
        next if user.streak_weeks.exists?(start: week.start)

        judged = StreakWeek.judge(multiplier: user.xp_multiplier, freezes: user.streak_freezes, days: [ first, week.start ].max..week.finish,
                                  journaled: journal_days(week), excused: excused_days)
        user.streak_weeks.create!(start: week.start, multiplier_before: user.xp_multiplier, freezes_before: user.streak_freezes, **judged.attributes)
        user.update!(xp_multiplier: judged.multiplier, streak_freezes: judged.attributes[:freezes])
      end
    end
  end
end
