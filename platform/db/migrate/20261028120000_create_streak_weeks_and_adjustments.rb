class CreateStreakWeeksAndAdjustments < ActiveRecord::Migration[8.1]
  def change
    create_table :streak_weeks do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.date :start, null: false
      t.decimal :multiplier_before, precision: 3, scale: 2, null: false
      t.integer :freezes_before, null: false
      t.integer :missed, null: false
      t.integer :excused, null: false, default: 0
      t.decimal :multiplier, precision: 3, scale: 2, null: false
      t.integer :freezes, null: false
      t.timestamps
    end
    add_index :streak_weeks, %i[user_id start], unique: true
    add_index :streak_weeks, %i[start multiplier]

    create_table :streak_adjustments do |t|
      t.references :user, foreign_key: true
      t.references :admin, foreign_key: { to_table: :users }
      t.references :undone_by, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.date :starts_on
      t.date :ends_on
      t.integer :freezes
      t.decimal :multiplier, precision: 3, scale: 2
      t.boolean :reprice, null: false, default: true
      t.boolean :notify, null: false, default: false
      t.text :reason, null: false
      t.text :message
      t.jsonb :effect, null: false, default: {}
      t.datetime :discarded_at
      t.timestamps
    end
    add_index :streak_adjustments, :discarded_at
    add_index :streak_adjustments, :created_at
    add_index :streak_adjustments, %i[kind starts_on ends_on]
  end
end
