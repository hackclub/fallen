class CreateJournalDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_drafts do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.jsonb :parts, null: false, default: []
      t.timestamps
    end
    add_index :journal_drafts, %i[project_id user_id], unique: true
    add_index :journal_drafts, :parts, using: :gin, opclass: :jsonb_path_ops
  end
end
