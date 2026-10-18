class CreateTimeMilestones < ActiveRecord::Migration[8.1]
  def change
    create_table :time_milestones do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.datetime :since, null: false
      t.integer :minutes, null: false
      t.datetime :created_at, null: false
    end
    add_index :time_milestones, %i[user_id since minutes], unique: true
  end
end
