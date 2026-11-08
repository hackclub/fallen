# Indexes for what journal review filters and sorts on: the queue's reason (filter, counts, front-of-queue order), a
# project's open to-dos, and a project's reviews by decision.
class IndexJournalReviewFilters < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :progress_statuses, [ :due_reason, :due_since ], where: "due_since IS NOT NULL AND flagged_at IS NULL", algorithm: :concurrently,
      name: "index_progress_statuses_queued_by_reason"
    add_index :review_todos, :project_id, where: "resolved_at IS NULL", algorithm: :concurrently, name: "index_review_todos_unresolved"
    add_index :progress_reviews, [ :project_id, :verdict ], algorithm: :concurrently
  end
end
