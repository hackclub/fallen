class AddChangesAndSourceToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :versions, :object_changes, :jsonb
    add_column :versions, :source, :string
  end
end
