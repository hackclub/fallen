# The team an entry counts for in the race: the person's pet when it was made, so switching later never moves XP
# already earned (XpEntry, TeamRace). The race reads a week by when its XP was made.
class AddPetToXpEntries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :xp_entries, :pet, :string
    add_index :xp_entries, %i[created_at pet], algorithm: :concurrently
  end
end
