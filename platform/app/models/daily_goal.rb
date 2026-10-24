# frozen_string_literal: true

# How many hours someone needs to journal each day, today until the deadline, to have the final stage's XP (Evolution) by it.
# Two answers: at the multiplier they have now, and the best case, where their team pays out in full from here on
# (Team#best_multipliers, Team#best_bonus_xp). Today's journal XP is counted back in, so the goal stays put while they
# work through it. Team wins are left out; no one can plan on them.
class DailyGoal
  DEADLINE = Time.find_zone!("America/New_York").local(2026, 12, 11, 23, 59, 59)

  # Nil for someone without a pet, once they have the XP, or after the deadline.
  def self.for(user, team: user.team, now: Time.current)
    goal = new(user, team, now)
    goal if team && now <= DEADLINE && goal.xp_to_go.positive?
  end

  # The goal with each pet for someone starting today, so the egg picker can compare them. No queries: the
  # newcomer is never saved. Nil after the deadline.
  def self.preview(user, now: Time.current)
    return if now > DEADLINE

    goals = User::PETS.to_h do |pet|
      newcomer = User.new(timezone: user.timezone, pet: pet)
      [ pet, new(newcomer, newcomer.team, now) ]
    end
    any = goals.values.first
    { days_left: any.days.count, minutes: any.minutes, best_minutes: goals.transform_values(&:best_minutes) }
  end

  attr_reader :user, :team, :today

  def initialize(user, team, now)
    @user = user
    @team = team
    @today = user.local_date(now)
  end

  def days = today..user.local_date(DEADLINE)

  def xp_to_go = @xp_to_go ||= [ Evolution::STAGE_XP.last - user.xp + team.journal_xp(team.week(today)).fetch(today, 0), 0 ].max

  def minutes = minutes_for([ user.xp_multiplier ] * days.count)

  def best_minutes = minutes_for(team.best_multipliers(days), bonus: team.best_bonus_xp(days))

  def as_json(*)
    { deadline: DEADLINE.iso8601, days_left: days.count, minutes: minutes, best_minutes: best_minutes }
  end

  private

  # Minutes a day that, at each day's multiplier, add up to the XP still needed after `bonus`. Multipliers are in
  # hundredths, so they are summed exactly and a goal of exactly 450 minutes is not shown as 451.
  def minutes_for(multipliers, bonus: 0)
    xp = [ xp_to_go - bonus, 0 ].max
    (xp * 60 / (XpEntry::PER_HOUR * multipliers.sum { |m| m.to_r.round(2) })).ceil
  end
end
