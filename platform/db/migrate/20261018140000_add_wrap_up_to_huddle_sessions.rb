class AddWrapUpToHuddleSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :huddle_sessions, :dm_channel_id, :string
    add_column :huddle_sessions, :prompt_dm_ts, :string
    add_column :huddle_sessions, :wrap_up_asked_at, :datetime
    add_column :huddle_sessions, :done, :text
  end
end
