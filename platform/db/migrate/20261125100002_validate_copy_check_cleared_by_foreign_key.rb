class ValidateCopyCheckClearedByForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :submissions, :users, column: :copy_check_cleared_by_id
  end
end
