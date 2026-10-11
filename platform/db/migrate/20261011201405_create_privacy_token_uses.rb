class CreatePrivacyTokenUses < ActiveRecord::Migration[8.1]
  def change
    create_table :privacy_token_uses, id: false do |t|
      t.text :jti, null: false, primary_key: true
      t.datetime :used_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
  end
end
