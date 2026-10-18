class AddLapseTimelapseToJournals < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # One timelapse backs one live journal; a deleted journal frees it.
  def change
    add_reference :journals, :lapse_timelapse, index: false, foreign_key: { validate: false }
    add_index :journals, :lapse_timelapse_id, unique: true, where: "lapse_timelapse_id IS NOT NULL AND discarded_at IS NULL", algorithm: :concurrently
  end
end
