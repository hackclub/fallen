class CreateMcpActions < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_actions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :admin_token, null: false, foreign_key: true
      t.string :tool, null: false
      t.string :kind, null: false
      t.string :status, null: false
      t.jsonb :arguments, null: false, default: {}
      t.jsonb :result
      t.string :subject_type
      t.bigint :subject_id
      t.integer :duration_ms
      t.text :error

      t.timestamps
    end
    add_index :mcp_actions, :created_at
    add_index :mcp_actions, %i[subject_type subject_id]
  end
end
