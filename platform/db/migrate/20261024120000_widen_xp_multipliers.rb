# Sami's step is 0.15, so multipliers need hundredths. Both tables are a few thousand rows at most, so the rewrite
# holds its lock for milliseconds.
class WidenXpMultipliers < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      change_column :users, :xp_multiplier, :decimal, precision: 3, scale: 2, default: "1.0", null: false
      change_column :xp_entries, :multiplier, :decimal, precision: 3, scale: 2
    end
  end

  def down
    safety_assured do
      change_column :users, :xp_multiplier, :decimal, precision: 2, scale: 1, default: "1.0", null: false
      change_column :xp_entries, :multiplier, :decimal, precision: 2, scale: 1
    end
  end
end
