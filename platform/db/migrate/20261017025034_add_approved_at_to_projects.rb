class AddApprovedAtToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :approved_at, :datetime
  end
end
