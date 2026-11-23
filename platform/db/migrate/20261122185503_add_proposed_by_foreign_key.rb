class AddProposedByForeignKey < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :submissions, :users, column: :proposed_by_id, validate: false
  end
end
