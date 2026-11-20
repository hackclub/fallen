class AddAiGeneratedToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :ai_generated, :boolean, default: false, null: false
  end
end
