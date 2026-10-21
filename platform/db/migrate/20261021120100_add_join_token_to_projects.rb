class AddJoinTokenToProjects < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :projects, :join_token, :string
    add_index :projects, :join_token, unique: true, algorithm: :concurrently
  end
end
