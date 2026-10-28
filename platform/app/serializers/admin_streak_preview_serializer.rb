# frozen_string_literal: true

# Admin-only. What a streak change would do (StreakReplay::Plan), shown before it is made.
class AdminStreakPreviewSerializer < ApplicationSerializer
  typelize multiplier: "number[]", freezes: "number[]", xp: :number, journals: :number, restored: :number, broken: :number, open_days: "string[]",
    weeks: "{ start: string; outcome: string[]; multiplier: number[]; freezes: number[] }[]",
    bonuses: "{ start: string; finish: string; pay: boolean; xp: number }[]"

  attribute(:multiplier) { |plan| plan.multiplier.map(&:to_f) }
  attribute(:freezes, &:freezes)
  attribute(:xp, &:xp)
  attribute(:journals) { |plan| plan.reprices.size }
  attribute(:restored, &:restored)
  attribute(:broken, &:broken)
  attribute(:open_days) { |plan| plan.open_days.map(&:iso8601) }
  attribute(:weeks) do |plan|
    plan.changes.map do |change|
      week = change.week
      after = change.attributes
      { start: week.start.iso8601, outcome: [ week.outcome, change.broken? ? "broken" : (after[:missed].positive? ? "frozen" : "kept") ],
        multiplier: [ week.multiplier.to_f, after[:multiplier].to_f ], freezes: [ week.freezes, after[:freezes] ] }
    end
  end
  attribute(:bonuses) do |plan|
    plan.bonuses.map { { start: it.week.start.iso8601, finish: it.week.finish.iso8601, pay: it.pay?, xp: it.xp } }
  end
end
