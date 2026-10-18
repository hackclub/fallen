class AddTimelapseIdsToJournalDrafts < ActiveRecord::Migration[8.1]
  def change
    add_column :journal_drafts, :timelapse_ids, :jsonb, null: false, default: []
  end
end
