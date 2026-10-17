class AddXpToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :xp, :integer, null: false, default: 0
    add_column :users, :xp_multiplier, :decimal, precision: 2, scale: 1, null: false, default: 1.0
    add_column :users, :streak_freezes, :integer, null: false, default: 3
  end
end
