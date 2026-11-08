# Journal review follow-ups: what a check back asks the team to fix (review_todos), the XP held back until a reviewer
# sees it fixed (progress_xp_holds), a team asking for a review themselves (progress_statuses.requested_*), and when
# each reviewed project became due, for how long reviews take (progress_reviews.due_since).
class AddReviewFollowups < ActiveRecord::Migration[8.1]
  def change
    create_table :review_todos do |t|
      t.references :project, null: false, foreign_key: true
      t.references :progress_review, null: false, foreign_key: true
      t.text :body, null: false
      t.integer :position, null: false, default: 0
      t.datetime :done_at
      t.references :done_by, foreign_key: { to_table: :users }
      t.datetime :resolved_at
      t.timestamps
    end

    create_table :progress_xp_holds do |t|
      t.references :project, null: false, foreign_key: true
      t.references :progress_review, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :amount, null: false
      t.datetime :released_at
      # The journal review approval that gave it back; nil when the design approval or deleting the project did.
      t.references :released_by_review, foreign_key: { to_table: :progress_reviews }
      t.timestamps
    end

    add_column :progress_statuses, :requested_at, :datetime
    add_column :progress_statuses, :request_note, :text
    add_column :progress_reviews, :due_since, :datetime
  end
end
