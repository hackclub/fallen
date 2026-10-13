class AddSlackUserTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slack_user_token, :text
    add_column :users, :slack_user_token_scopes, :string
  end
end
