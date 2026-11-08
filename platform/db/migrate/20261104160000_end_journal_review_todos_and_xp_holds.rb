# Journal review no longer asks the team to fix things or holds XP back: resolves the to-dos still open and gives back
# every XP hold, so nobody is left waiting on a review that won't ask about them again.
class EndJournalReviewTodosAndXpHolds < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    ReviewTodo.where(resolved_at: nil).update_all(resolved_at: Time.current, updated_at: Time.current)
    ProgressXpHold.held.includes(:user).find_each(&:release!)
  end

  def down; end
end
