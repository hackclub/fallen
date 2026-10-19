# Someone can skip connecting Slack (SlackAuthController#skip); their projects and journals are then posted by the
# bot under their name and picture (SlackMessaging). The bot can only edit or delete its own messages and a user token
# only theirs, so each message remembers which one posted it.
class AddSlackSkipAndBotPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slack_skipped_at, :datetime
    add_column :projects, :slack_posted_by_bot, :boolean, default: false, null: false
    add_column :journals, :slack_posted_by_bot, :boolean, default: false, null: false
  end
end
