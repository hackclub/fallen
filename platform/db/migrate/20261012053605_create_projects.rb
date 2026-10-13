class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :repo_url
      t.string :demo_url
      t.string :slack_channel_id
      t.string :slack_thread_ts
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :projects, :discarded_at
    add_index :projects, %i[slack_channel_id slack_thread_ts], unique: true, where: "slack_thread_ts IS NOT NULL"
  end
end
