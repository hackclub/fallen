# The email signup bonus is once per person, kept by the database so two saves at once can't both pay it.
class IndexXpEntriesOneEmailSignupPerUser < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :xp_entries, :user_id, unique: true, where: "kind = 'email_signup'", name: "index_xp_entries_one_email_signup_per_user", algorithm: :concurrently
  end
end
