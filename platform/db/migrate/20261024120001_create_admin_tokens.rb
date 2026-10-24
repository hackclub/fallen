class CreateAdminTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_hint, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.datetime :expires_at, null: false

      t.timestamps
    end
    add_index :admin_tokens, :token_digest, unique: true
  end
end
