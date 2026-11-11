class AddDraftSavedAtAndReachOutToProjectTransfers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :project_transfers, :draft_saved_at, :datetime
    add_column :project_transfers, :reached_out_at, :datetime
    add_reference :project_transfers, :reached_out_by, index: { algorithm: :concurrently }
  end
end
