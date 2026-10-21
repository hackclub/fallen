class CreateActiveDays < ActiveRecord::Migration[8.1]
  def change
    create_table :active_days, primary_key: %i[user_id day] do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.date :day, null: false
    end
    add_index :active_days, :day
  end
end
