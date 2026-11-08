class CreateWorkshopRsvps < ActiveRecord::Migration[8.1]
  def change
    create_table :workshop_rsvps do |t|
      t.string :email, null: false
      t.string :slack_username
      t.string :slot, null: false
      t.timestamps
    end
    add_index :workshop_rsvps, :email, unique: true
    add_index :workshop_rsvps, %i[slot created_at]
  end
end
