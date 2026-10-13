class CreateJournals < ActiveRecord::Migration[8.1]
  def change
    create_table :journals do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.integer :duration_minutes
      t.string :source, null: false, default: "web"
      t.string :slack_channel_id
      t.string :slack_ts
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :journals, :discarded_at
    add_index :journals, %i[slack_channel_id slack_ts], unique: true, where: "slack_ts IS NOT NULL"
  end
end
