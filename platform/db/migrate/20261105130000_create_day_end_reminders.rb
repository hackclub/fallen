class CreateDayEndReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :day_end_reminders do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.date :reminded_on
      t.timestamps
    end
  end
end
