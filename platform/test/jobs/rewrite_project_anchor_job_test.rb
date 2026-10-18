require "test_helper"

class RewriteProjectAnchorJobTest < ActiveJob::TestCase
  OLD_FOOTER = { "type" => "context", "block_id" => SlackMessages::FOOTER_BLOCK_ID, "elements" => [ { "type" => "mrkdwn", "text" => "<https://x.test|fallen ↗>" } ] }.freeze

  test "rewrites an untouched anchor as the owner, without the footer" do
    project = projects(:station)
    with_fake_slack do |slack|
      anchor(slack, project, "blocks" => [ { "type" => "section" }, OLD_FOOTER ])
      assert_equal :rewritten, RewriteProjectAnchorJob.perform_now(project)

      call = slack.calls_to(:chat_update).sole
      assert_equal [ "CJOURNALS", project.slack_thread_ts ], call.values_at(:channel, :ts)
      assert_equal "Project name: Weather station\n\nESP32 and a BME280", call[:text]
      assert_equal [ "section" ], call[:blocks].map { |block| block[:type] }
    end
  end

  test "rewrites anchors from before the footer existed" do
    project = projects(:station)
    with_fake_slack do |slack|
      anchor(slack, project, "text" => ":hammer_and_wrench: *Weather station*", "blocks" => [ { "type" => "rich_text" } ])
      assert_equal :rewritten, RewriteProjectAnchorJob.perform_now(project)
      assert_equal "Project name: Weather station\n\nESP32 and a BME280", slack.calls_to(:chat_update).sole[:text]
    end
  end

  test "dry run only reports" do
    with_fake_slack do |slack|
      anchor(slack, projects(:station), {})
      assert_equal :would_rewrite, RewriteProjectAnchorJob.perform_now(projects(:station), dry_run: true)
      assert_empty slack.calls_to(:chat_update)
    end
  end

  test "leaves anchors the person edited in Slack, already rewritten, posted by someone else, or gone" do
    project = projects(:station)
    with_fake_slack do |slack|
      anchor(slack, project, "edited" => { "user" => project.user.slack_id, "ts" => "1700000500.000000" })
      assert_equal :edited_in_slack, RewriteProjectAnchorJob.perform_now(project)

      anchor(slack, project, "text" => "Project name: Weather station", "edited" => { "user" => project.user.slack_id, "ts" => "1700000500.000000" })
      assert_equal :already_rewritten, RewriteProjectAnchorJob.perform_now(project)

      anchor(slack, project, "user" => "USOMEONE")
      assert_equal :not_theirs, RewriteProjectAnchorJob.perform_now(project)

      anchor(slack, project, "ts" => "1700000000.000999")
      assert_equal :gone, RewriteProjectAnchorJob.perform_now(project)

      assert_empty slack.calls_to(:chat_update)
    end
  end

  test "skips projects off Slack and owners without a token" do
    with_fake_slack do |slack|
      assert_equal :not_linked, RewriteProjectAnchorJob.perform_now(projects(:unlinked))
      users(:member).disconnect_slack!
      assert_equal :not_connected, RewriteProjectAnchorJob.perform_now(projects(:station).reload)
      assert_empty slack.calls
    end
  end

  private

  def anchor(slack, project, fields)
    message = { "ts" => project.slack_thread_ts, "user" => project.user.slack_id, "text" => "Idea: #{project.title}" }.merge(fields)
    slack.define_singleton_method(:conversations_replies) do |**args|
      calls << [ :conversations_replies, args ]
      Slack::Messages::Message.new("ok" => true, "messages" => [ message ])
    end
  end
end
