require "test_helper"

class HatchCelebrationJobTest < ActiveJob::TestCase
  test "the pet posts in the thread of the first journal, as itself" do
    with_fake_slack do |slack|
      HatchCelebrationJob.perform_now(users(:member))
      message = slack.calls_to(:chat_postMessage).sole
      project = journals(:first).project
      assert_equal [ project.slack_channel_id, project.slack_thread_ts ], message.values_at(:channel, :thread_ts)
      assert_equal "Lulu", message[:username]
      assert message[:icon_url].end_with?("/static-assets/pets/lulu-pfp.png")
      assert message[:text].start_with?(":yay-cat: YAY YOU DID IT!! :yay-cat:")
      assert message[:text].end_with?("*p.s. check your mail! we have a note for you :3c:*")
      assert_includes message[:text], "\n\n- lulu\n\n"
    end
  end

  test "nothing without a journal on Slack" do
    with_fake_slack do |slack|
      HatchCelebrationJob.perform_now(users(:newcomer))
      assert_empty slack.calls_to(:chat_postMessage)
    end
  end
end
