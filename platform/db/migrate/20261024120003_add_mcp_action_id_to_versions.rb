class AddMcpActionIdToVersions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :versions, :mcp_action_id, :bigint
    add_index :versions, :mcp_action_id, algorithm: :concurrently
  end
end
