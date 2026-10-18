class AddTrackedTimeToJournals < ActiveRecord::Migration[8.1]
  def change
    add_column :journals, :tracked_minutes, :integer
    add_column :journals, :hours_self_claimed, :boolean
  end
end
