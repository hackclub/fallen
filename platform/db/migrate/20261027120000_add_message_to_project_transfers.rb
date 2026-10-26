class AddMessageToProjectTransfers < ActiveRecord::Migration[8.1]
  def change
    add_column :project_transfers, :message, :text
  end
end
