class CreateMcpSqlChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_sql_changes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :admin_token, null: false, foreign_key: true
      t.references :reviewer, foreign_key: { to_table: :users }
      t.text :sql, null: false
      t.string :kind, null: false
      t.string :table_name, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :preview, null: false, default: {}
      t.integer :rows_affected
      t.text :error
      t.datetime :expires_at, null: false
      t.datetime :resolved_at

      t.timestamps
    end
    add_index :mcp_sql_changes, :created_at
  end
end
