class AddHuddleTrackingDetail < ActiveRecord::Migration[8.1]
  def change
    create_table :huddle_events do |t|
      t.string :call_id, null: false
      t.string :slack_id, null: false
      t.string :kind, null: false
      t.datetime :occurred_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :huddle_events, %i[call_id slack_id occurred_at]
    add_index :huddle_events, :slack_id

    add_column :huddle_sessions, :last_seen_at, :datetime
    add_column :huddle_sessions, :join_source, :string
    add_column :huddle_sessions, :leave_source, :string
    add_column :huddle_sessions, :screenshare_since, :datetime
    add_column :huddle_sessions, :screenshare_seconds, :integer, null: false, default: 0
    add_column :huddle_sessions, :camera_since, :datetime
    add_column :huddle_sessions, :camera_seconds, :integer, null: false, default: 0
  end
end
