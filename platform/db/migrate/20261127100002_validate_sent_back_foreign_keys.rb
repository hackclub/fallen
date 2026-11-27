class ValidateSentBackForeignKeys < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :submissions, :users, column: :sent_back_by_id
    validate_foreign_key :submissions, :users, column: :sent_back_to_id
  end
end
