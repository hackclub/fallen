class ValidateReviewDraftByForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :submissions, :users, column: :review_draft_by_id
  end
end
