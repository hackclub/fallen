# A design reviewer's decision held for an admin to sign off before it applies (SubmissionReview#propose,
# Admin::SignOffsController).
class AddProposedReviewToSubmissions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :submissions, :proposed_review, :jsonb
    add_column :submissions, :proposed_at, :datetime
    add_reference :submissions, :proposed_by, index: { algorithm: :concurrently }
    add_index :submissions, :proposed_at, algorithm: :concurrently
  end
end
