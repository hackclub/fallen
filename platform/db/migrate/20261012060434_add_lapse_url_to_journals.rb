class AddLapseUrlToJournals < ActiveRecord::Migration[8.1]
  def change
    add_column :journals, :lapse_url, :string
  end
end
