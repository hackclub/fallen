class IndexTrackedTimeEnds < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :huddle_sessions, :left_at, algorithm: :concurrently
    add_index :huddle_pauses, :ended_at, algorithm: :concurrently
    add_index :timer_sessions, :stopped_at, algorithm: :concurrently
  end
end
