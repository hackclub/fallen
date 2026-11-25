class AddHCAScopesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hca_scopes, :string
  end
end
