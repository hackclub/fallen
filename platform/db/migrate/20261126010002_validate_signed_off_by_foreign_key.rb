class ValidateSignedOffByForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :submissions, :users, column: :signed_off_by_id
  end
end
