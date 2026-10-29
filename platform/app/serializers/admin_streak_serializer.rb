# frozen_string_literal: true

# Admin-only. Someone's streak on /admin/users/:id (StreakCalendar), with the numbers the restore forms check against.
class AdminStreakSerializer < ApplicationSerializer
  JUDGED = "{ start: string; outcome: 'kept' | 'frozen' | 'broken'; multiplier_before: number; multiplier: number; freezes_before: number; " \
           "freezes: number; missed: number; excused: number }"

  typelize team: "'lulu' | 'sami' | null", multiplier: :number, freezes: :number, today: :string, first_day: [ :string, nullable: true ],
    rows: "{ start: string; finish: string; status: 'kept' | 'frozen' | 'broken' | 'open' | 'paid' | 'unpaid' | 'unjudged'; counted: number; " \
          "bonus_xp: number | null; days: { date: string; state: 'before' | 'journal' | 'excused' | 'missed' | 'frozen' | 'today' | 'future'; " \
          "xp: number | null; excuse_id: string | null }[]; judged: #{JUDGED} | null }[]",
    judged: "#{JUDGED}[]",
    rules: "{ multipliers: number[]; step: number; max_freezes: number; max_xp: number; max_excuse_days: number; lulu_days: number; lulu_bonus: number }"

  attribute(:team, &:team)
  attribute(:multiplier) { |calendar| calendar.user.xp_multiplier.to_f }
  attribute(:freezes) { |calendar| calendar.user.streak_freezes }
  attribute(:today) { |calendar| calendar.today.iso8601 }
  attribute(:first_day) { |calendar| calendar.first_day&.iso8601 }
  attribute(:judged) { |calendar| calendar.judged.map { judged_week(it) } }
  attribute(:rows) do |calendar|
    calendar.rows.map do |row|
      { start: row.start.iso8601, finish: row.finish.iso8601, status: row.status, counted: row.counted, bonus_xp: row.bonus_xp,
        judged: row.judged && judged_week(row.judged), days: row.days.map { |day| { date: day.date.iso8601, state: day.state, xp: day.xp, excuse_id: day.excuse_id } } }
    end
  end
  attribute(:rules) do
    { multipliers: Team::Sami.multipliers.map(&:to_f), step: Team::Sami::STEP, max_freezes: StreakAdjustment::MAX_FREEZES, max_xp: StreakAdjustment::MAX_XP,
      max_excuse_days: StreakAdjustment::MAX_EXCUSE_DAYS, lulu_days: Team::Lulu::DAYS_FOR_BONUS, lulu_bonus: Team::Lulu::WEEKLY_BONUS }
  end
  many :adjustments, resource: AdminStreakAdjustmentSerializer

  helper do
    def judged_week(week)
      { start: week.start.iso8601, outcome: week.outcome, multiplier_before: week.multiplier_before.to_f, multiplier: week.multiplier.to_f,
        freezes_before: week.freezes_before, freezes: week.freezes, missed: week.missed, excused: week.excused }
    end
  end
end
