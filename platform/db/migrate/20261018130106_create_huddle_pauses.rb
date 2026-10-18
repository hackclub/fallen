class CreateHuddlePauses < ActiveRecord::Migration[8.1]
  def change
    create_table :huddle_pauses do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.string :end_reason
      t.timestamps
    end
    add_index :huddle_pauses, %i[user_id started_at]
    add_index :huddle_pauses, :user_id, unique: true, where: "ended_at IS NULL", name: "index_huddle_pauses_one_open_per_user"
  end
end
