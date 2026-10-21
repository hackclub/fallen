class AddBilledToWritingChecks < ActiveRecord::Migration[8.1]
  def change
    add_column :writing_checks, :billed, :boolean, null: false, default: true
  end
end
