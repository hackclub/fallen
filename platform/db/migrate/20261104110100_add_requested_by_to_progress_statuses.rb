# Who on the team asked for a journal review (ProgressStatus#requested_by).
class AddRequestedByToProgressStatuses < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :progress_statuses, :requested_by, index: { algorithm: :concurrently }
  end
end
