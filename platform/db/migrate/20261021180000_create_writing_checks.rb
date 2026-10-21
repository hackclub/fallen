class CreateWritingChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :writing_checks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :journal, foreign_key: true
      t.text :body, null: false
      t.string :status, null: false, default: "pending"
      t.float :fraction_ai
      t.float :fraction_ai_assisted
      t.boolean :insisted, null: false, default: false
      t.string :slack_ts
      t.timestamps
    end
  end
end
