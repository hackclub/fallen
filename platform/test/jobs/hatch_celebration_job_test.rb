require "test_helper"

class HatchCelebrationJobTest < ActiveJob::TestCase
  test "the pet posts in the thread of the first journal, as itself" do
    with_fake_slack do |slack|
      thread(slack, [ { "ts" => journals(:first).project.slack_thread_ts } ])
      HatchCelebrationJob.perform_now(users(:member))
      message = slack.calls_to(:chat_postMessage).sole
      project = journals(:first).project
      assert_equal [ project.slack_channel_id, project.slack_thread_ts ], message.values_at(:channel, :thread_ts)
      assert_equal "Lulu", message[:username]
      assert message[:icon_url].end_with?("/static-assets/pets/lulu-pfp.png")
      assert message[:text].start_with?(":yay-cat: YAY YOU DID IT!! :yay-cat:")
      assert_equal "context", message[:blocks].last[:type]
      assert_equal "p.s. check your mailbox in a few days! (the physical one) we have a note for you :3c:", message[:blocks].last[:elements].sole[:text]
      assert_includes message[:text], "\n\n- lulu\n\n"
    end
  end

  test "nothing without a journal on Slack" do
    with_fake_slack do |slack|
      HatchCelebrationJob.perform_now(users(:newcomer))
      assert_empty slack.calls_to(:chat_postMessage)
    end
  end

  test "nothing when the thread was deleted from Slack" do
    with_fake_slack do |slack|
      thread(slack, [])
      HatchCelebrationJob.perform_now(users(:member))
      assert_empty slack.calls_to(:chat_postMessage)

      thread(slack, Slack::Web::Api::Errors::ThreadNotFound.new("thread_not_found"))
      HatchCelebrationJob.perform_now(users(:member))
      assert_empty slack.calls_to(:chat_postMessage)
    end
  end

  private

  def thread(slack, messages)
    slack.define_singleton_method(:conversations_replies) do |**args|
      calls << [ :conversations_replies, args ]
      raise messages if messages.is_a?(Exception)

      Slack::Messages::Message.new("ok" => true, "messages" => messages)
    end
  end
end
