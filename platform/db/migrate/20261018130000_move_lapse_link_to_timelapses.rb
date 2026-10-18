class MoveLapseLinkToTimelapses < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # A journal can now take its hours from several timelapses, so each timelapse points at its journal instead.
  def up
    add_reference :lapse_timelapses, :journal, index: { algorithm: :concurrently }, foreign_key: { validate: false }
    safety_assured do
      execute <<~SQL
        UPDATE lapse_timelapses SET journal_id = journals.id
        FROM journals WHERE journals.lapse_timelapse_id = lapse_timelapses.id
      SQL
    end
    remove_foreign_key :journals, :lapse_timelapses
    remove_index :journals, :lapse_timelapse_id, algorithm: :concurrently
  end

  def down
    add_index :journals, :lapse_timelapse_id, unique: true, where: "lapse_timelapse_id IS NOT NULL AND discarded_at IS NULL", algorithm: :concurrently
    add_foreign_key :journals, :lapse_timelapses, validate: false
    remove_reference :lapse_timelapses, :journal, index: { algorithm: :concurrently }
  end
end
