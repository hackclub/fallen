require "test_helper"

class StupendousBonusJobTest < ActiveJob::TestCase
  test "a new journal that says stupendous earns a DM from the bot" do
    user = users(:member)
    with_fake_slack do |slack|
      perform_enqueued_jobs(only: StupendousBonusJob) do
        projects(:station).journals.create!(user: user, body: journal_text("Stupendous"), duration: "1h", images: [ photo ])
      end
      message = slack.calls_to(:chat_postMessage).sole
      assert_equal user.slack_id, message[:channel]
      assert_equal "heya! you just received a stupendous +20 XP :)", message[:text]
    end
  end

  test "nothing for someone without Slack linked" do
    entry = users(:member).xp_entries.create!(kind: "stupendous", amount: XpEntry::STUPENDOUS_BONUS, day: Date.current)
    users(:member).update_column(:slack_id, nil)
    with_fake_slack do |slack|
      StupendousBonusJob.perform_now(entry)
      assert_empty slack.calls_to(:chat_postMessage)
    end
  end
end
