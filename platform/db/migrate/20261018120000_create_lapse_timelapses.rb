class CreateLapseTimelapses < ActiveRecord::Migration[8.1]
  def change
    create_table :lapse_timelapses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :lapse_id, null: false, index: { unique: true }
      t.string :name
      t.integer :duration_seconds, null: false, default: 0
      t.string :visibility
      t.string :playback_url
      t.string :thumbnail_url
      t.datetime :recorded_at, index: true
      t.timestamps
    end

    add_column :users, :lapse_token, :text
    add_column :users, :lapse_synced_at, :datetime
  end
end
