class CreateSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :repo_snapshots do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :url, null: false
      t.string :status, null: false, default: "pending"
      t.string :host
      t.string :branch
      t.string :commit_sha
      t.jsonb :tree, null: false, default: []
      t.boolean :tree_truncated, null: false, default: false
      t.text :readme
      t.string :readme_path
      t.text :bom_csv
      t.string :bom_path
      t.text :error
      t.datetime :fetched_at
      t.timestamps
    end

    create_table :submissions do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :repo_snapshot, foreign_key: true
      t.string :kind, null: false, default: "design"
      t.string :status, null: false, default: "pending"
      t.string :repo_url, null: false
      t.string :commit_sha
      t.string :made_with, array: true, null: false, default: []
      t.jsonb :checks, null: false, default: []
      t.text :note
      t.text :bom_csv
      t.integer :requested_cents, null: false, default: 0
      t.integer :approved_cents
      t.references :reviewer, foreign_key: { to_table: :users }
      t.references :claimed_by, foreign_key: { to_table: :users }
      t.datetime :claim_expires_at
      t.jsonb :rubric, null: false, default: {}
      t.text :feedback
      t.text :internal_reason
      t.datetime :decided_at
      t.datetime :flagged_at
      t.text :flag_reason
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :submissions, %i[status created_at]
    add_index :submissions, :project_id, unique: true, where: "status = 'pending'", name: "index_submissions_one_pending_per_project"

    create_table :bom_items do |t|
      t.references :submission, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :kind, null: false, default: "part"
      t.string :name, null: false
      t.string :purpose
      t.integer :quantity, null: false, default: 1
      t.integer :unit_cents
      t.integer :total_cents, null: false
      t.string :link
      t.string :vendor
      t.boolean :owned, null: false, default: false
      t.string :verdict
      t.string :reason
      t.integer :approved_cents
      t.timestamps
    end

    create_table :journal_reviews do |t|
      t.references :submission, null: false, foreign_key: true
      t.references :journal, null: false, foreign_key: true
      t.references :reviewer, foreign_key: { to_table: :users }
      t.integer :approved_minutes, null: false
      t.string :reason
      t.text :note
      t.timestamps
    end
    add_index :journal_reviews, %i[submission_id journal_id], unique: true

    create_table :reviewer_notes do |t|
      t.references :project, null: false, foreign_key: true
      t.references :submission, foreign_key: true
      t.references :user, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end

    add_column :journals, :reviewed_minutes, :integer

    create_table :hcb_connections do |t|
      t.references :connected_by, null: false, foreign_key: { to_table: :users }
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      t.timestamps
    end

    create_table :hcb_grant_cards do |t|
      t.references :user, null: false, foreign_key: true
      t.string :hcb_id
      t.string :email
      t.integer :amount_cents, null: false
      t.integer :balance_cents
      t.string :status, null: false, default: "active"
      t.datetime :last_synced_at
      t.timestamps
    end
    add_index :hcb_grant_cards, :hcb_id, unique: true
    add_index :hcb_grant_cards, :user_id, unique: true, where: "status = 'active'", name: "index_hcb_grant_cards_one_active_per_user"

    create_table :grant_payouts do |t|
      t.references :submission, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :hcb_grant_card, foreign_key: true
      t.references :sent_by, foreign_key: { to_table: :users }
      t.integer :amount_cents, null: false
      t.string :status, null: false, default: "pending"
      t.string :via, null: false, default: "auto"
      t.string :hcb_reference
      t.text :error
      t.datetime :sent_at
      t.timestamps
    end
    add_index :grant_payouts, :submission_id, unique: true, name: "index_grant_payouts_one_per_submission"
    add_index :grant_payouts, :status
  end
end
