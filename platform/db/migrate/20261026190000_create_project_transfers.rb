class CreateProjectTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :project_transfers do |t|
      t.string :airtable_id, null: false
      t.references :user, foreign_key: true
      t.references :reviewer, foreign_key: { to_table: :users }
      t.references :project, foreign_key: true
      t.string :email, null: false
      t.string :name
      t.string :project_name
      t.string :source_url, null: false
      t.string :source
      t.string :source_ref
      t.string :fallen_project_url
      t.integer :claimed_minutes
      t.string :status, null: false, default: "pending"
      t.jsonb :snapshot
      t.datetime :fetched_at
      t.text :error
      t.integer :approved_minutes
      t.integer :xp
      t.text :note
      t.datetime :decided_at
      t.datetime :submitted_at, null: false
      t.datetime :discarded_at
      t.timestamps

      t.index :airtable_id, unique: true
      t.index :email
      t.index %i[source source_ref]
      t.index :status
      t.index :submitted_at
      t.index :discarded_at
      t.index :source, where: "fetched_at IS NULL", name: "index_project_transfers_unfetched"
    end
  end
end
