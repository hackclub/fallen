# Someone can start with just an email (TrialSessionsController) and sign in with Hack Club Auth later, which fills
# this in (User.from_hca_code!).
class AllowTrialUsersWithoutHCA < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :hca_id, true
  end
end
