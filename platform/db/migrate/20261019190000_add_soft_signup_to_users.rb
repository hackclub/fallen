class AddSoftSignupToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :soft_signup, :string
  end
end
