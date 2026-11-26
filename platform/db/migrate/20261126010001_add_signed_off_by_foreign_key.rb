class AddSignedOffByForeignKey < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :submissions, :users, column: :signed_off_by_id, validate: false
  end
end
