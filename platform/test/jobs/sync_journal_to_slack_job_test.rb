require "test_helper"

class SyncJournalToSlackJobTest < ActiveJob::TestCase
  test "posts a web journal into the thread as the author" do
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text("**Soldered** the [board](https://x.test)"), duration_minutes: 60, source: "web", lapse_url: "https://lapse.hackclub.com/t/1", images: [ photo ])

    with_fake_slack do |slack|
      SyncJournalToSlackJob.perform_now(journal, "create")
      call = slack.calls_to(:chat_postMessage).first
      assert_equal "CJOURNALS", call[:channel]
      assert_equal projects(:station).slack_thread_ts, call[:thread_ts]
      assert_nil call[:username]
      assert call[:text].start_with?("*Soldered* the <https://x.test|board>. Wrote down"), call[:text]
      assert_includes call[:text], "photo.png>"
      refute_includes call[:blocks].to_s, "lapse.hackclub.com"
    end
    assert journal.reload.on_slack?
  end

  test "refuses to post for someone who has not connected slack" do
    users(:member).disconnect_slack!
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text("x"), duration_minutes: 30, source: "web", images: [ photo ])
    with_fake_slack do |slack|
      assert_raises(SlackMessaging::NotConnected) { SyncJournalToSlackJob.perform_now(journal, "create") }
      assert_empty slack.calls
    end
  end

  test "posts the project anchor first when the project is not on slack yet" do
    journal = journals(:web_only)
    with_fake_slack do |slack|
      SyncJournalToSlackJob.perform_now(journal, "create")
      assert_empty slack.calls
      assert_enqueued_with(job: PostProjectToSlackJob, args: [ projects(:unlinked) ])

      PostProjectToSlackJob.perform_now(projects(:unlinked))
      assert projects(:unlinked).reload.slack_linked?
      assert_equal [ "section" ], slack.calls_to(:chat_postMessage).sole[:blocks].map { |block| block[:type] }
      assert_enqueued_with(job: SyncJournalToSlackJob, args: [ journal, "create" ])
    end
  end

  test "invites someone who is not in the journals channel and posts again" do
    with_fake_slack do |slack|
      refused = false
      slack.define_singleton_method(:chat_postMessage) do |params|
        next super(**params) if refused

        refused = true
        raise Slack::Web::Api::Errors::NotInChannel, "not_in_channel"
      end

      PostProjectToSlackJob.perform_now(projects(:unlinked))
      assert_equal [ { channel: "CJOURNALS", users: projects(:unlinked).user.slack_id } ], slack.calls_to(:conversations_invite)
      assert projects(:unlinked).reload.slack_linked?
    end
  end

  test "edits and deletes follow the message" do
    with_fake_slack do |slack|
      SyncJournalToSlackJob.perform_now(journals(:first), "update")
      SyncJournalToSlackJob.perform_now(journals(:first), "delete")
      assert_equal journals(:first).slack_ts, slack.calls_to(:chat_update).first[:ts]
      assert_equal journals(:first).slack_ts, slack.calls_to(:chat_delete).first[:ts]
    end
  end
end
