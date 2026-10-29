# XP an admin gave (or took back) with a StreakAdjustment of kind "xp", logged like the streak's other changes.
class AddXpToStreakAdjustments < ActiveRecord::Migration[8.1]
  def change
    add_column :streak_adjustments, :xp, :integer
  end
end
