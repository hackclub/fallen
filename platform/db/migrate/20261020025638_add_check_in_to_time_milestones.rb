class AddCheckInToTimeMilestones < ActiveRecord::Migration[8.1]
  def change
    add_column :time_milestones, :done, :text
    add_column :time_milestones, :answered_at, :datetime
    add_column :time_milestones, :dm_channel_id, :string
    add_column :time_milestones, :dm_ts, :string
  end
end
