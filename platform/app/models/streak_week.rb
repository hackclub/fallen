# A Monday-to-Sunday week Team Sami judged for one person (Team::Sami#close_week), with the multiplier and freezes
# they had going in, so it can be judged again when days are excused later (StreakReplay). Days count from the first
# journal; each one without a journal or an excuse (StreakAdjustment) spends a freeze, and one with none left drops
# the multiplier back to 1. A week kept, with freezes or not, raises it STEP.
# == Schema Information
#
# Table name: streak_weeks
#
#  id                :bigint           not null, primary key
#  excused           :integer          default(0), not null
#  freezes           :integer          not null
#  freezes_before    :integer          not null
#  missed            :integer          not null
#  multiplier        :decimal(3, 2)    not null
#  multiplier_before :decimal(3, 2)    not null
#  start             :date             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_streak_weeks_on_start_and_multiplier  (start,multiplier)
#  index_streak_weeks_on_user_id_and_start     (user_id,start) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class StreakWeek < ApplicationRecord
  has_paper_trail

  belongs_to :user

  Judgment = Data.define(:missed, :excused, :multiplier, :freezes) do
    def broken? = freezes.negative?
    def attributes = { missed: missed, excused: excused, multiplier: multiplier, freezes: [ freezes, 0 ].max }
  end

  scope :broken, -> { where("freezes_before < missed") }

  # `days` are the ones counted (from the first journal), `journaled` and `excused` the days with each.
  def self.judge(multiplier:, freezes:, days:, journaled:, excused:)
    unjournaled = days.to_a - journaled.to_a
    missed = unjournaled.count { !excused.include?(it) }
    settle(multiplier:, freezes:, missed:, excused: unjournaled.size - missed)
  end

  def self.settle(multiplier:, freezes:, missed:, excused:)
    left = freezes - missed
    after = left.negative? ? 1.0.to_d : [ multiplier.to_d + Team::Sami::STEP.to_d, Team::Sami::MAX_MULTIPLIER.to_d ].min
    Judgment.new(missed: missed, excused: excused, multiplier: after, freezes: left)
  end

  def week = Week.new(start: start)
  def broken? = freezes_before < missed
  def frozen? = !broken? && missed.positive?
  def outcome = broken? ? "broken" : (frozen? ? "frozen" : "kept")
end
