class AddCopyCheckClearedByForeignKey < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :submissions, :users, column: :copy_check_cleared_by_id, validate: false
  end
end
