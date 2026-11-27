class AddSentBackForeignKeys < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :submissions, :users, column: :sent_back_by_id, validate: false
    add_foreign_key :submissions, :users, column: :sent_back_to_id, validate: false
  end
end
