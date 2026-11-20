class AddYswsAirtableIdToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :ysws_airtable_id, :string
  end
end
