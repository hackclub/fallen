require "test_helper"

class AddJournalFooterJobTest < ActiveJob::TestCase
  RICH_TEXT = { "type" => "rich_text", "block_id" => "abc", "elements" => [ { "type" => "rich_text_section", "elements" => [ { "type" => "text", "text" => "two", "style" => { "bold" => true } } ] } ] }.freeze

  test "adds the footer to the last reply as the person, keeping what they wrote" do
    journal = slack_journal
    with_fake_slack do |slack|
      replies(slack, { "ts" => "1700000010.000200", "text" => "*two*", "blocks" => [ RICH_TEXT ] })
      AddJournalFooterJob.perform_now(journal)

      call = slack.calls_to(:chat_update).sole
      assert_equal [ "CJOURNALS", "1700000010.000200", "*two*" ], call.values_at(:channel, :ts, :text)
      assert_equal RICH_TEXT, call[:blocks].first.deep_stringify_keys
      assert_includes call[:blocks].last[:elements].sole[:text], "#journal-#{journal.public_id}|fallen ↗>"
      assert_equal "1700000010.000200", slack.calls_to(:conversations_replies).sole[:latest]
    end
  end

  test "leaves a reply that already has the footer, and people without a slack token" do
    journal = slack_journal
    with_fake_slack do |slack|
      replies(slack, { "ts" => "1700000010.000200", "text" => "two", "blocks" => [ RICH_TEXT, SlackMessages.footer("https://x.test") ] })
      AddJournalFooterJob.perform_now(journal)
      assert_empty slack.calls_to(:chat_update)

      users(:member).disconnect_slack!
      AddJournalFooterJob.perform_now(journal.reload)
      assert_equal 1, slack.calls_to(:conversations_replies).size
    end
  end

  private

  def slack_journal
    projects(:station).journals.create!(user: users(:member), body: "one\n\ntwo", duration_minutes: 30, source: "slack", slack_channel_id: "CJOURNALS", slack_ts: "1700000010.000100",
                                        images: [ photo ], slack_parts: [ { ts: "1700000010.000100", text: "one" }, { ts: "1700000010.000200", text: "two" } ])
  end

  def replies(slack, *messages)
    slack.define_singleton_method(:conversations_replies) do |**args|
      calls << [ :conversations_replies, args ]
      Slack::Messages::Message.new("ok" => true, "messages" => messages)
    end
  end
end
