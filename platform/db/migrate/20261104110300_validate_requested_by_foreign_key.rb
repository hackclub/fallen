class ValidateRequestedByForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :progress_statuses, :users, column: :requested_by_id
  end
end
