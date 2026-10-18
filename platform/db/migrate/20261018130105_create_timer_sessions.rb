class CreateTimerSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :timer_sessions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.datetime :started_at, null: false
      t.datetime :stopped_at
      t.timestamps
    end
    add_index :timer_sessions, %i[user_id started_at]
    add_index :timer_sessions, :user_id, unique: true, where: "stopped_at IS NULL", name: "index_timer_sessions_one_running_per_user"

    add_column :huddles, :link, :string
  end
end
