class AddHuddleMessageCounts < ActiveRecord::Migration[8.1]
  def change
    add_column :huddles, :message_count, :integer, null: false, default: 0
    add_column :huddle_sessions, :prompted_at_count, :integer
  end
end
