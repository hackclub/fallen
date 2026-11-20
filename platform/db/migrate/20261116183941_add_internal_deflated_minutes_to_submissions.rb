class AddInternalDeflatedMinutesToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :internal_deflated_minutes, :integer
  end
end
