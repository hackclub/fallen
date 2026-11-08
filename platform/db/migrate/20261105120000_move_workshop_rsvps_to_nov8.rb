# The first Tamagotchi workshop moved from Saturday Nov 7 to Sunday Nov 8, same time; keep earlier sign-ups on it.
# One update on a small table, so nothing is locked for long.
class MoveWorkshopRsvpsToNov8 < ActiveRecord::Migration[8.1]
  def up
    safety_assured { execute "UPDATE workshop_rsvps SET slot = 'nov8' WHERE slot = 'nov7'" }
  end

  def down
    safety_assured { execute "UPDATE workshop_rsvps SET slot = 'nov7' WHERE slot = 'nov8'" }
  end
end
