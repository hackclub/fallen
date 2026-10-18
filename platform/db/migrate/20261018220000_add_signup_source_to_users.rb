class AddSignupSourceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :signup_source, :jsonb, default: {}, null: false
  end
end
