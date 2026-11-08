# The review's reply in its project's thread, so the team's DMs can link to it and an edit can rewrite it.
class AddSlackTsToProgressReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :progress_reviews, :slack_ts, :string
  end
end
