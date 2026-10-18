class AddHatchSeenAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hatch_seen_at, :datetime
  end
end
