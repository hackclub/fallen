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
      assert_equal [ "photo.png" ], call[:attachments].map { |attachment| attachment[:fallback] }
      assert call[:attachments].sole[:image_url].start_with?("http"), call[:attachments]
      refute_includes call[:blocks].to_s, "lapse.hackclub.com"
    end
    assert journal.reload.on_slack?
  end

  test "leaves the photos the editor embedded out of the text, since they go under the message" do
    image = photo
    upload = "/rails/active_storage/blobs/redirect/#{image.signed_id}/board.png"
    body = "#{journal_text('Soldered the board')}\n![board.png](#{upload})\n![power](image.p\n![wiring.png](#{upload})\nng)\n\n\n![logo](https://x.test/logo.png) done"
    # Written before outside pictures were refused, as older journals were.
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text, duration_minutes: 60, source: "web", images: [ image ])
    journal.update_column(:body, body)

    with_fake_slack do |slack|
      SyncJournalToSlackJob.perform_now(journal, "create")
      text = slack.calls_to(:chat_postMessage).sole[:text]
      refute_includes text, "active_storage"
      refute_includes text, "image.p"
      assert_includes text, "<https://x.test/logo.png|logo> done"
      refute_includes text, "\n\n\n"
    end
  end

  test "leaves transferred journals off Slack" do
    journal = projects(:station).journals.create!(user: users(:member), body: "Written in another program.", duration_minutes: 60, source: "transfer")

    with_fake_slack do |slack|
      SyncJournalToSlackJob.perform_now(journal, "create")
      assert_empty slack.calls_to(:chat_postMessage)
    end
    assert_not journal.reload.on_slack?
  end

  test "splits a journal longer than one slack section across several" do
    paragraph = "Wired the amp and tested every key on the board. " * 20
    journal = projects(:station).journals.create!(user: users(:member), body: Array.new(8, paragraph.strip).join("\n\n"), duration_minutes: 60, source: "web", images: [ photo ])

    with_fake_slack do |slack|
      SyncJournalToSlackJob.perform_now(journal, "create")
      sections = slack.calls_to(:chat_postMessage).sole[:blocks].select { |block| block[:type] == "section" }
      assert_operator sections.size, :>, 1
      assert sections.all? { |section| section[:text][:text].length <= SlackBot::Blocks::SECTION_LIMIT }
    end
  end

  test "refuses to post for someone who has not connected slack" do
    users(:member).disconnect_slack!
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text("x"), duration_minutes: 30, source: "web", images: [ photo ])
    with_fake_slack do |slack|
      SyncJournalToSlackJob.perform_now(journal, "create")
      assert_empty slack.calls
    end
    assert_not journal.reload.on_slack?
  end

  test "drops the journal when the token stops working for someone who never skipped, to post once they reconnect" do
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text("x"), duration_minutes: 30, source: "web", images: [ photo ])

    with_fake_slack do |slack|
      slack.define_singleton_method(:chat_postMessage) { |_params| raise Slack::Web::Api::Errors::TokenRevoked, "token_revoked" }
      SyncJournalToSlackJob.perform_now(journal, "create")
    end
    assert_not users(:member).reload.slack_connected?
    assert_not journal.reload.on_slack?
  end

  test "posts through the bot under their name for someone who skipped slack, and edits and deletes as the bot" do
    users(:member).disconnect_slack!
    users(:member).skip_slack!
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text("Tuned the strings"), duration_minutes: 30, source: "web", images: [ photo ])

    with_fake_slack do |slack|
      SyncJournalToSlackJob.perform_now(journal, "create")
      call = slack.calls_to(:chat_postMessage).sole
      assert_equal "Member Person", call[:username]
      assert_equal "#{User::CACHET_URL}/users/U0MEMBER/r", call[:icon_url]
      assert journal.reload.slack_posted_by_bot?

      # The user client would refuse: they are not connected. The bot owns these messages.
      SyncJournalToSlackJob.perform_now(journal, "update")
      SyncJournalToSlackJob.perform_now(journal, "delete")
      assert_equal [ journal.slack_ts ], slack.calls_to(:chat_update).map { |update| update[:ts] }
      assert_equal [ journal.slack_ts ], slack.calls_to(:chat_delete).map { |delete| delete[:ts] }
    end
  end

  test "falls back to the bot when the token stops working for someone who skipped before" do
    users(:member).skip_slack!
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text("x"), duration_minutes: 30, source: "web", images: [ photo ])

    with_fake_slack do |slack|
      revoked = false
      slack.define_singleton_method(:chat_postMessage) do |params|
        next super(**params) if revoked

        revoked = true
        raise Slack::Web::Api::Errors::TokenRevoked, "token_revoked"
      end

      SyncJournalToSlackJob.perform_now(journal, "create")
      assert_equal "Member Person", slack.calls_to(:chat_postMessage).sole[:username]
    end
    assert_not users(:member).reload.slack_connected?
    assert journal.reload.slack_posted_by_bot?
  end

  test "does not post through the bot for someone whose slack account was deactivated" do
    users(:member).disconnect_slack!
    users(:member).skip_slack!
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text("x"), duration_minutes: 30, source: "web", images: [ photo ])

    with_fake_slack do |slack|
      slack.define_singleton_method(:users_info) { |**| Slack::Messages::Message.new("ok" => true, "user" => { "id" => "U0MEMBER", "deleted" => true }) }
      SyncJournalToSlackJob.perform_now(journal, "create")
      assert_empty slack.calls_to(:chat_postMessage)
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

  test "subscribes someone who skipped slack to the thread the bot started for them" do
    projects(:unlinked).user.disconnect_slack!
    projects(:unlinked).user.skip_slack!

    with_fake_slack do |slack|
      PostProjectToSlackJob.perform_now(projects(:unlinked))
      anchor, ping = slack.calls_to(:chat_postMessage)
      thread_ts = projects(:unlinked).reload.slack_thread_ts
      assert_nil anchor[:thread_ts]
      assert_equal [ thread_ts, "<@#{projects(:unlinked).user.slack_id}>" ], ping.values_at(:thread_ts, :text)
      assert_equal 1, slack.calls_to(:chat_delete).size
      refute_equal thread_ts, slack.calls_to(:chat_delete).sole[:ts]
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
