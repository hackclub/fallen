class AddLapseReviewToProjectTransfers < ActiveRecord::Migration[8.1]
  def change
    add_column :project_transfers, :hackatime_user_id, :string
    add_column :project_transfers, :hackatime_projects, :string, array: true, default: [], null: false
    add_column :project_transfers, :lapse_recordings, :jsonb
    add_column :project_transfers, :lapse_annotations, :jsonb, default: {}, null: false
    add_column :project_transfers, :lapse_seconds, :integer
    add_column :project_transfers, :lapse_fetched_at, :datetime
    add_column :project_transfers, :lapse_error, :text
  end
end
