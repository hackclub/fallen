# frozen_string_literal: true

# Admin-only. A week Team Sami judged (StreakWeek), in /admin/streaks.
class AdminStreakWeekSerializer < ApplicationSerializer
  typelize start: :string, outcome: "'kept' | 'frozen' | 'broken'", multiplier_before: :number, multiplier: :number, freezes_before: :number,
    freezes: :number, missed: :number, excused: :number

  attributes :start, :freezes_before, :freezes, :missed, :excused
  attribute(:outcome, &:outcome)
  attribute(:multiplier_before) { |week| week.multiplier_before.to_f }
  attribute(:multiplier) { |week| week.multiplier.to_f }
  one :user, resource: AdminUserSerializer
end
