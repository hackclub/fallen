class AddSlackPartsToJournals < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :journals, :slack_parts, :jsonb, null: false, default: []
    add_index :journals, :slack_parts, using: :gin, opclass: :jsonb_path_ops, algorithm: :concurrently
  end
end
