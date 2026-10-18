class AddAirtableSyncedAtToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :users, :airtable_synced_at, :datetime
    add_index :users, :airtable_synced_at, algorithm: :concurrently
  end
end
