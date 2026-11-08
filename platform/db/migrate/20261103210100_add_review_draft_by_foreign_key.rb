class AddReviewDraftByForeignKey < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :submissions, :users, column: :review_draft_by_id, validate: false
  end
end
