# A journal reviewer's note on particular journals ({ journal public id => note }), sent to the team with the feedback.
class AddJournalNotesToProgressReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :progress_reviews, :journal_notes, :jsonb, null: false, default: {}
  end
end
