# A held decision an admin sent back to the queue (SubmissionReview.send_back): who sent it back, and the reviewer it
# goes back to, so it stays theirs and comes first in their queue.
class AddSentBackToSubmissions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :submissions, :sent_back_at, :datetime
    add_reference :submissions, :sent_back_by, index: { algorithm: :concurrently }
    add_reference :submissions, :sent_back_to, index: { algorithm: :concurrently }
  end
end
