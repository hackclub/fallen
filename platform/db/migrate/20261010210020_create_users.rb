class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :hca_id, null: false
      t.string :email, null: false
      t.string :display_name, null: false
      t.string :avatar
      t.string :slack_id
      t.string :timezone, null: false, default: "UTC"
      t.string :roles, array: true, null: false, default: []
      t.string :verification_status
      t.boolean :is_adult, null: false, default: false
      t.boolean :is_banned, null: false, default: false
      t.text :hca_token
      t.datetime :last_seen_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :users, :hca_id, unique: true
    add_index :users, :email
    add_index :users, :slack_id
    add_index :users, :roles, using: :gin
    add_index :users, :discarded_at
  end
end
