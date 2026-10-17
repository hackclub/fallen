class CreateXpEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :xp_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :amount, null: false
      t.decimal :multiplier, precision: 2, scale: 1
      t.date :day, null: false
      t.references :source, polymorphic: true, index: false
      t.timestamps
    end

    add_index :xp_entries, [ :user_id, :day ]
    add_index :xp_entries, [ :source_type, :source_id ], unique: true, where: "source_id IS NOT NULL"
    add_index :xp_entries, [ :user_id, :kind, :day ], unique: true, where: "source_id IS NULL"
  end
end
