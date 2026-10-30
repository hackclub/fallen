# When Slack stopped letting anyone else into the huddle (Huddle#full!).
class AddFullAtToHuddles < ActiveRecord::Migration[8.1]
  def change
    add_column :huddles, :full_at, :datetime
  end
end
