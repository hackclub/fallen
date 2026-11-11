class ValidateReachedOutByForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :project_transfers, :users, column: :reached_out_by_id
  end
end
