# Each entry's team, from the person's pet changes in their history: the pet after the last change before the entry
# was made, else the one before the first change, else the pet they have. One UPDATE: a few thousand rows, the
# versions found by their (item_type, item_id) index.
class BackfillXpEntryPets < ActiveRecord::Migration[8.1]
  def up
    safety_assured { execute <<~SQL }
      UPDATE xp_entries SET pet = COALESCE(
        (SELECT v.object_changes -> 'pet' ->> 1 FROM versions v
          WHERE v.item_type = 'User' AND v.item_id = xp_entries.user_id AND v.object_changes ? 'pet' AND v.created_at <= xp_entries.created_at
          ORDER BY v.created_at DESC, v.id DESC LIMIT 1),
        (SELECT COALESCE(v.object_changes -> 'pet' ->> 0, v.object_changes -> 'pet' ->> 1) FROM versions v
          WHERE v.item_type = 'User' AND v.item_id = xp_entries.user_id AND v.object_changes ? 'pet'
          ORDER BY v.created_at, v.id LIMIT 1),
        (SELECT users.pet FROM users WHERE users.id = xp_entries.user_id))
      WHERE pet IS NULL
    SQL
  end

  def down; end
end
