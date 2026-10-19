# Switching pets (and so teams) is limited to once a week after the first journal (PetSwitch).
class AddPetSwitchedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :pet_switched_at, :datetime
  end
end
