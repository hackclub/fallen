class AddAddedByForeignKey < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :progress_statuses, :users, column: :added_by_id, validate: false
  end
end
