# Pays the email signup bonus to everyone who signed up from the email before it existed.
class BackfillEmailSignupBonus < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    User.kept.where(is_banned: false).where("signup_source->>'utm_source' = ?", XpEntry::EMAIL_SIGNUP_SOURCE).find_each do |user|
      XpEntry.grant_email_signup(user)
    end
  end

  def down; end
end
