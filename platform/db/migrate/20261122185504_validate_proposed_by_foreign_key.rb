class ValidateProposedByForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :submissions, :users, column: :proposed_by_id
  end
end
