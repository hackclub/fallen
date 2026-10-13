require "test_helper"

class JournalFlowTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  CHANNEL = "CJOURNALS"

  test "a thread reply by the owner becomes a journal" do
    with_fake_slack do |slack|
      assert_difference -> { Journal.count }, 1 do
        handle_message(user: "U0MEMBER", thread_ts: projects(:station).slack_thread_ts, ts: "1700000003.000100", text: "Printed the case")
      end
      journal = Journal.last
      assert_equal "slack", journal.source
      assert_equal "1700000003.000100", journal.slack_ts
      assert_equal MessageEvent::SAVED_EMOJI, slack.calls_to(:reactions_add).first[:name]
      prompt = slack.calls_to(:chat_postEphemeral).first
      assert_equal "journal_time:#{journal.public_id}", prompt[:blocks].last[:elements].first[:action_id]
    end
  end

  test "log time opens a typed duration modal and saves it" do
    journal = journals(:pending_hours)
    with_fake_slack do |slack|
      SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => "U0MEMBER" }, "trigger_id" => "t", "response_url" => "https://hooks.slack.test/r",
                                       "actions" => [ { "action_id" => "journal_time:#{journal.public_id}", "value" => "" } ] })
      assert_equal "journal_time", slack.calls_to(:views_open).first[:view][:callback_id]

      bad = SlackBot.handle(:interaction, view_submission("journal_time", { "duration" => "ages" }, metadata: { journal_id: journal.public_id }, user: "U0MEMBER"))
      assert_equal "errors", bad[:response_action]
      SlackBot.handle(:interaction, view_submission("journal_time", { "duration" => "1h 15m" }, metadata: { journal_id: journal.public_id, response_url: "https://hooks.slack.test/r" }, user: "U0MEMBER"))
      assert_equal 75, journal.reload.duration_minutes
      assert_equal true, slack.calls_to(:response_url).last[:body]["replace_original"]
    end
  end

  test "replies by other people and unknown threads are ignored" do
    with_fake_slack do
      assert_no_difference -> { Journal.count } do
        handle_message(user: "U0ADMIN", thread_ts: projects(:station).slack_thread_ts, ts: "1700000004.000100", text: "nice!")
        handle_message(user: "U0MEMBER", thread_ts: "1699999999.000000", ts: "1700000005.000100", text: "lost")
        handle_message(user: "U0MEMBER", thread_ts: projects(:station).slack_thread_ts, ts: journals(:first).slack_ts, text: "dupe")
      end
    end
  end

  test "a web journal echoed back from slack is not duplicated" do
    projects(:station).journals.create!(user: users(:member), body: "Posted on the site", source: "web")
    with_fake_slack do
      assert_no_difference -> { Journal.count } do
        handle_message(user: "U0MEMBER", thread_ts: projects(:station).slack_thread_ts, ts: "1700000006.000100", text: "Posted on the site")
      end
    end
  end

  test "a top level message in the journals channel gets a nudge" do
    with_fake_slack do |slack|
      handle_message(user: "U0MEMBER", ts: "1700000007.000100", text: "starting a drone")
      nudge = slack.calls_to(:chat_postEphemeral).first
      assert_equal "project_from_message", nudge[:blocks].last[:elements].first[:action_id]
      assert_equal "1700000007.000100", nudge[:blocks].last[:elements].first[:value]

      slack.calls.clear
      handle_message(user: "U0MEMBER", channel: "CELSEWHERE", ts: "1700000008.000100", text: "chat")
      assert_empty slack.calls
    end
  end

  test "edits and deletions in slack update the journal" do
    with_fake_slack do
      SlackBot.handle(:event, { "event" => { "type" => "message", "subtype" => "message_changed", "channel" => CHANNEL,
                                              "message" => { "ts" => journals(:first).slack_ts, "text" => "Soldered it properly", "user" => "U0MEMBER" } } })
      assert_equal "Soldered it properly", journals(:first).reload.body

      SlackBot.handle(:event, { "event" => { "type" => "message", "subtype" => "message_deleted", "channel" => CHANNEL, "deleted_ts" => journals(:first).slack_ts } })
      assert journals(:first).reload.discarded?
    end
  end

  test "the project modal anchors a project to the person's message" do
    with_fake_slack do |slack|
      assert_difference -> { Project.count }, 1 do
        SlackBot.handle(:interaction, view_submission("project", { "title" => "Drone", "description" => "quad", "repo_url" => "" },
                                                      metadata: { channel_id: CHANNEL, anchor_ts: "1700000007.000100" }, user: "U0MEMBER"))
      end
      project = Project.last
      assert_equal users(:member), project.user
      assert_equal "1700000007.000100", project.slack_thread_ts
      assert_equal "1700000007.000100", slack.calls_to(:chat_postMessage).first[:thread_ts]
    end
  end

  test "the project modal without an anchor posts one from a job" do
    with_fake_slack do
      assert_enqueued_with(job: PostProjectToSlackJob) do
        SlackBot.handle(:interaction, view_submission("project", { "title" => "Drone" }, metadata: { channel_id: CHANNEL }, user: "U0MEMBER"))
      end
    end
  end

  test "the manifest subscribes to channel messages and asks for a user scope" do
    manifest = SlackBot::Manifest.generate(app_url: "https://example.com")
    assert_includes manifest.dig("settings", "event_subscriptions", "bot_events"), "message.channels"
    assert_includes manifest.dig("oauth_config", "scopes", "user"), "chat:write"
    assert_includes manifest.dig("features", "slash_commands").map { |c| c["command"] }, "/project"
  end

  private

  def handle_message(user:, ts:, text:, thread_ts: nil, channel: CHANNEL)
    event = { "type" => "message", "user" => user, "channel" => channel, "ts" => ts, "text" => text, "thread_ts" => thread_ts }.compact
    SlackBot.handle(:event, { "type" => "event_callback", "event" => event })
  end

  def view_submission(callback_id, values, metadata:, user:)
    state = values.transform_values { |v| { "input" => { "type" => "plain_text_input", "value" => v } } }
    { "type" => "view_submission", "user" => { "id" => user }, "view" => { "callback_id" => callback_id, "private_metadata" => metadata.to_json, "state" => { "values" => state } } }
  end
end
