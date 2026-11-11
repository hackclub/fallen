class AddReachedOutByForeignKey < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :project_transfers, :users, column: :reached_out_by_id, validate: false
  end
end
