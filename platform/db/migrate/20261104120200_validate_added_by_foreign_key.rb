class ValidateAddedByForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :progress_statuses, :users, column: :added_by_id
  end
end
