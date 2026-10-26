# Pays the bonus for journals written before it existed: each person's first one that says the word.
class BackfillStupendousBonus < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    Journal.kept.where("body ILIKE ?", "%stupendous%").includes(:user).find_each do |journal|
      XpEntry.grant_stupendous(journal)
    end
  end

  def down; end
end
