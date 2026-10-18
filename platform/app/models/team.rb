# frozen_string_literal: true

# Lulu or Sami. The pet picked in onboarding is also the team, and each team rewards a week of journaling its own
# way: Lulu pays a bonus for enough journal days in each week counted from the person's first journal, Sami raises
# the multiplier on every journal for each Monday-to-Sunday week without a gap, with a few freezes
# (users.streak_freezes) to cover missed days. `Team.close_week` settles a calendar week for everyone (CloseWeekJob):
# the team that earned the most XP gets WIN_BONUS for each member who earned some, then Sami judges its members' week.
# `Team.settle` pays Lulu's weeks as each person's ends (SettleLuluWeeksJob).
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
    reward_winners(week)
    User.on_a_team.find_each { |user| user.team.close_week(week) }
  end

  def self.settle
    User.on_a_team.where(pet: "lulu").find_each { |user| user.team.settle }
  end

  def self.reward_winners(week)
    totals = XpEntry.team_totals(week)
    best = totals.values.max.to_i
    return if best.zero?

    winners = totals.select { |_, xp| xp == best }.keys
    contributors = User.on_a_team.where(pet: winners).where(id: XpEntry.during(week).where("amount > 0").select(:user_id))
    contributors.find_each do |user|
      user.xp_entries.create_or_find_by!(kind: "team_win", day: week.finish) { |entry| entry.amount = WIN_BONUS }
    end
  end

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def name = self.class.name.demodulize.downcase

  # Days of the week with a journal, on the person's calendar.
  def journal_days(week) = user.xp_entries.journals.during(week).distinct.pluck(:day).sort

  # The streak starts with the first journal.
  def first_journal_day = user.xp_entries.kept.journals.minimum(:day)

  # The week the person's team counts `day` in.
  def week(day) = Week.of(day)

  # Judges a Monday-to-Sunday week that has ended.
  def close_week(week) = nil

  class Lulu < Team
    DAYS_FOR_BONUS = 5
    WEEKLY_BONUS = 30

    # Seven days from the first journal, then the next seven, and so on. Before any journal, the week would start
    # today. Discarded journals still count as the first, so deleting one never shifts weeks already paid.
    def week(day)
      first = user.xp_entries.journals.minimum(:day) || day
      Week.new(start: first + (day - first).to_i / 7 * 7)
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
      return if journal_days(week).size < DAYS_FOR_BONUS
      return if user.xp_entries.kept.where(kind: "weekly_bonus", day: week.start..week.finish + 6).exists?

      user.xp_entries.create_or_find_by!(kind: "weekly_bonus", day: week.finish) { |entry| entry.amount = WEEKLY_BONUS }
    end
  end

  class Sami < Team
    STEP = 0.1
    MAX_MULTIPLIER = 1.5

    # Each missed day spends a freeze; a miss with none left drops the multiplier back to 1. A week kept (freezes or
    # not) raises it. The result is written once per week as a `streak` entry worth 0 XP.
    def close_week(week)
      first = first_journal_day
      return if first.nil? || first > week.finish

      freezes = user.streak_freezes - missed_days(week, since: first)
      multiplier = freezes.negative? ? 1.0 : [ user.xp_multiplier + STEP, MAX_MULTIPLIER ].min
      user.transaction do
        entry = user.xp_entries.create_or_find_by!(kind: "streak", day: week.finish) { |e| e.assign_attributes(amount: 0, multiplier: multiplier) }
        user.update!(xp_multiplier: multiplier, streak_freezes: [ freezes, 0 ].max) if entry.previously_new_record?
      end
    end

    private

    def missed_days(week, since:) = ([ since, week.start ].max..week.finish).count - journal_days(week).size
  end
end
