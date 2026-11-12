class CreateHcbOrgGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :hcb_org_grants do |t|
      t.string :hcb_id, null: false, index: { unique: true }
      t.string :email, null: false, index: true
      t.references :user, foreign_key: true
      t.integer :amount_cents, null: false
      t.integer :balance_cents
      t.string :status, null: false
      t.date :expires_on
      t.string :purpose
      t.datetime :ignored_at
      t.references :ignored_by, foreign_key: { to_table: :users }
      t.datetime :synced_at, null: false
      t.timestamps
    end

    add_column :hcb_connections, :ledger_checked_at, :datetime
    add_column :hcb_connections, :ledger_error, :text
  end
end
