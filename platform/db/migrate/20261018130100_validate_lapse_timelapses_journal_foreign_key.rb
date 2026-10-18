class ValidateLapseTimelapsesJournalForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :lapse_timelapses, :journals
  end
end
