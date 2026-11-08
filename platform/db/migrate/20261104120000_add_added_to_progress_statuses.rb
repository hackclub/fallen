# An admin putting a project in the journal review queue by its link (ProgressStatus.add), whatever its hours.
class AddAddedToProgressStatuses < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :progress_statuses, :added_at, :datetime
    add_reference :progress_statuses, :added_by, index: { algorithm: :concurrently }
  end
end
