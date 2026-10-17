class AddDiscardedAtToXpEntries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :xp_entries, :discarded_at, :datetime
    add_index :xp_entries, :discarded_at, algorithm: :concurrently
  end
end
