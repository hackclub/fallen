# An unfinished review, saved as the reviewer works (Review::SubmissionsController#draft), so leaving the page never
# loses it and whoever opens the submission next carries on from it.
class AddReviewDraftToSubmissions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :submissions, :review_draft, :jsonb
    add_column :submissions, :review_draft_at, :datetime
    add_reference :submissions, :review_draft_by, index: { algorithm: :concurrently }
  end
end
