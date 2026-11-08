# Journal review (ProgressReview): reviewers read a project's journals as hours build up, not only at submission.
# progress_statuses is one row per project that has reached the queue: when it's due and why, the next threshold,
# the claim, and the AI flag and star. progress_reviews is each decision made on it.
class CreateProgressReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :progress_statuses do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.datetime :due_since
      t.string :due_reason
      t.integer :logged_minutes, null: false, default: 0
      t.integer :next_at_minutes, null: false
      t.datetime :waiting_since
      t.integer :approvals_count, null: false, default: 0
      t.integer :reviews_count, null: false, default: 0
      t.datetime :last_reviewed_at
      t.references :claimed_by, foreign_key: { to_table: :users }
      t.datetime :claim_expires_at
      t.datetime :flagged_at
      t.text :flag_reason
      t.references :flagged_by, foreign_key: { to_table: :users }
      t.datetime :starred_at
      t.references :starred_by, foreign_key: { to_table: :users }
      t.timestamps
      t.index :due_since, where: "due_since IS NOT NULL AND flagged_at IS NULL", name: "index_progress_statuses_queued"
      t.index :flagged_at, where: "flagged_at IS NOT NULL"
      t.index :starred_at, where: "starred_at IS NOT NULL"
    end

    create_table :progress_reviews do |t|
      t.references :project, null: false, foreign_key: true
      t.references :reviewer, foreign_key: { to_table: :users }
      t.string :verdict, null: false
      t.string :due_reason
      t.jsonb :checks, null: false, default: {}
      t.text :feedback
      t.integer :logged_minutes, null: false
      t.timestamps
      t.index :created_at
    end
  end
end
