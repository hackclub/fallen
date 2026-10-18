class AddPromptUrlToJournalDrafts < ActiveRecord::Migration[8.1]
  def change
    add_column :journal_drafts, :prompt_url, :string
    add_column :journal_drafts, :prompt_url_at, :datetime
  end
end
