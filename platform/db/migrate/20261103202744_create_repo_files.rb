class CreateRepoFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :repo_files do |t|
      t.references :repo_snapshot, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :path, null: false
      t.string :status, null: false, default: "pending"
      t.text :error
      t.bigint :byte_size
      t.datetime :fetched_at
      t.timestamps
    end
    add_index :repo_files, %i[repo_snapshot_id path], unique: true
  end
end
