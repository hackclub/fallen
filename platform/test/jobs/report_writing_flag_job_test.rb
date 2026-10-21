require "test_helper"

class ReportWritingFlagJobTest < ActiveJob::TestCase
  setup do
    @check = WritingCheck.create!(user: users(:member), body: "I wrote <this> myself. " * 20, status: "done", fraction_ai: 0.93, fraction_ai_assisted: 0.05)
  end

  test "posts the flagged writing and who wrote it, posted or not" do
    with_fake_slack do |slack|
      with_env("SLACK_AI_FLAGS_CHANNEL_ID" => "CFLAGS") { ReportWritingFlagJob.perform_now(@check) }
      post = slack.calls_to(:chat_postMessage).sole
      assert_equal "CFLAGS", post[:channel]
      assert_includes post[:text], "93% AI-generated"
      assert_includes post[:text], users(:member).slack_mention
      assert_includes post[:text], "Not posted yet."
      assert_includes post[:text], "> I wrote &lt;this&gt; myself."
      assert_equal "1700009999.000001", @check.reload.slack_ts
    end
  end

  test "once it becomes a journal anyway, says so in the thread" do
    @check.update!(slack_ts: "1700000000.000001", journal: journals(:web_only), insisted: true)
    with_fake_slack do |slack|
      with_env("SLACK_AI_FLAGS_CHANNEL_ID" => "CFLAGS") { ReportWritingFlagJob.perform_now(@check) }
      reply = slack.calls_to(:chat_postMessage).sole
      assert_equal "1700000000.000001", reply[:thread_ts]
      assert_includes reply[:text], "after holding"
    end
  end

  test "posts nothing without the channel" do
    with_fake_slack do |slack|
      ReportWritingFlagJob.perform_now(@check)
      assert_empty slack.calls
    end
  end
end
