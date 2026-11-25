class AddAiDeclarationToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :used_ai, :boolean, default: false, null: false
    add_column :submissions, :ai_usage, :text
  end
end
