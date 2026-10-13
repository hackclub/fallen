# Columns the dashboard and the lists filter or sort by. Without these every one is a sequential scan.
class AddIndexesForListsAndDashboard < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :journals, :created_at, algorithm: :concurrently
    # Admin::DashboardController counts journals missing hours; the partial index stays small.
    add_index :journals, :project_id, where: "discarded_at IS NULL AND duration_minutes IS NULL",
              name: "index_journals_needing_hours", algorithm: :concurrently
    add_index :projects, :updated_at, algorithm: :concurrently
    add_index :users, :created_at, algorithm: :concurrently
    add_index :users, :last_seen_at, algorithm: :concurrently
  end
end
