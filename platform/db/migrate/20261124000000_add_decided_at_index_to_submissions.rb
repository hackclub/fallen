# The review leaderboard counts decisions in a date range (Admin::ReviewLeaderboardController).
class AddDecidedAtIndexToSubmissions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :submissions, :decided_at, algorithm: :concurrently
  end
end
