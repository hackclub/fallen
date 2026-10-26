# A journal now earns two kinds of entry: its hours and the one-time "stupendous" bonus. The bonus is once per
# person, kept by the database so two journals saved at once can't both pay it.
class IndexXpEntriesBySourceAndKind < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :xp_entries, [ :source_type, :source_id, :kind ], unique: true, where: "source_id IS NOT NULL", algorithm: :concurrently
    remove_index :xp_entries, [ :source_type, :source_id ], unique: true, where: "source_id IS NOT NULL", algorithm: :concurrently
    add_index :xp_entries, :user_id, unique: true, where: "kind = 'stupendous'", name: "index_xp_entries_one_stupendous_per_user", algorithm: :concurrently
  end
end
