class AddPetToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :pet, :string
  end
end
