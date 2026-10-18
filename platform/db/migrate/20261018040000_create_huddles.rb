class CreateHuddles < ActiveRecord::Migration[8.1]
  def change
    create_table :huddles do |t|
      t.string :call_id, null: false, index: { unique: true }
      t.string :channel_id, null: false
      t.string :thread_ts
      t.datetime :started_at, null: false
      t.datetime :ended_at, index: true
      t.datetime :handed_off_at
      t.timestamps
    end

    create_table :huddle_sessions do |t|
      t.references :huddle, null: false, foreign_key: true, index: false
      t.references :user, foreign_key: true
      t.string :slack_id, null: false, index: true
      t.datetime :joined_at, null: false
      t.datetime :left_at
      t.string :mode
      t.text :goal
      t.timestamps
    end
    add_index :huddle_sessions, %i[huddle_id slack_id]
    add_index :huddle_sessions, %i[huddle_id slack_id], unique: true, where: "left_at IS NULL", name: "index_huddle_sessions_one_open_per_person"
  end
end
