class AddGoalsAndHonestHoursToTime < ActiveRecord::Migration[8.1]
  def change
    add_column :timer_sessions, :goal, :text
    add_column :timer_sessions, :done, :text
    add_column :timer_sessions, :wrapped_up_at, :datetime
    add_column :timer_sessions, :deducted_seconds, :integer, default: 0, null: false
    add_column :huddle_sessions, :deducted_seconds, :integer, default: 0, null: false
  end
end
