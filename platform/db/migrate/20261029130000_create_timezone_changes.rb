# Each time someone's timezone changed, or a change was refused for coming too soon (User#change_timezone), for
# admins to see on /admin/users/:id. The calendar day a journal counts for follows the timezone.
class CreateTimezoneChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :timezone_changes do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :from, null: false
      t.string :to, null: false
      t.string :source, null: false
      t.boolean :refused, null: false, default: false
      t.datetime :created_at, null: false
    end
    add_index :timezone_changes, %i[user_id created_at]

    add_column :users, :timezone_changed_at, :datetime
  end
end
