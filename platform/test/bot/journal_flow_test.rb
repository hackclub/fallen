require "test_helper"

class JournalFlowTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  CHANNEL = "CJOURNALS"

  test "a thread reply by the owner waits for them to say it is a journal" do
    with_fake_slack do |slack|
      assert_no_difference -> { Journal.count } do
        assert_enqueued_with(job: JournalPromptJob, at: nil) { reply("Printed the case") }
      end
      assert_nil enqueued_jobs.last["scheduled_at"], "the first reply is asked about straight away"
      draft = JournalDraft.last
      assert_equal [ "Printed the case" ], draft.parts.pluck("text")

      perform_enqueued_jobs
      prompt = slack.calls_to(:chat_postEphemeral).first
      assert_equal projects(:station).slack_thread_ts, prompt[:thread_ts]
      assert_equal %w[duration lapse_url], prompt[:blocks].select { |block| block[:type] == "input" }.pluck(:block_id)
      buttons = prompt[:blocks].find { |block| block[:type] == "actions" }[:elements]
      assert_equal %w[journal_draft:journal journal_draft:more journal_draft:skip], buttons.pluck(:action_id)
      assert_equal [ draft.public_id ], buttons.pluck(:value).uniq
    end
  end

  test "several replies become one journal, and only with a time" do
    with_fake_slack do |slack|
      reply("Printed the case", ts: "1700000003.000100")
      reply("Then sanded it", ts: "1700000003.000200")
      perform_enqueued_jobs
      assert_equal 1, slack.calls_to(:chat_postEphemeral).size, "only the last reply's prompt is sent"

      draft = JournalDraft.last
      assert_no_difference -> { Journal.count } do
        press("journal", draft, duration: "")
        press("journal", draft, duration: "ages")
      end
      shown = slack.calls_to(:response_url).last[:body]
      assert_equal "ages", shown["blocks"].find { |block| block["block_id"] == "duration" }.dig("element", "initial_value")
      assert shown["blocks"].any? { |block| block.dig("elements", 0, "text").to_s.include?("should look like") }

      assert_difference -> { Journal.count }, 1 do
        assert_enqueued_with(job: CollectSlackJournalJob) { press("journal", draft, duration: "1h 15m") }
      end

      journal = Journal.last
      assert_equal "Printed the case\n\nThen sanded it", journal.body
      assert_equal 75, journal.duration_minutes
      assert_equal "1700000003.000100", journal.slack_ts
      assert_not JournalDraft.exists?(draft.id)
      assert_equal true, slack.calls_to(:response_url).last[:body]["replace_original"]

      perform_enqueued_jobs
      assert_equal %w[1700000003.000100 1700000003.000200], slack.calls_to(:reactions_add).pluck(:timestamp)
    end
  end

  test "add more keeps collecting" do
    with_fake_slack do |slack|
      reply("Printed the case")
      press("more", JournalDraft.last)
      assert_includes slack.calls_to(:response_url).last[:body]["text"], "Keep going"
      reply("and sanded it", ts: "1700000003.000200")
      assert_equal 2, JournalDraft.last.message_count
    end
  end

  test "a later reply waits for a pause before asking again" do
    with_fake_slack do
      reply("Printed the case")
      assert_enqueued_with(job: JournalPromptJob, at: JournalDraft::ASK_AFTER.from_now) { reply("Then sanded it", ts: "1700000003.000200") }
    end
  end

  test "not a journal on one message drops it, on several lets the person tick which belong" do
    with_fake_slack do |slack|
      reply("Printed the case", ts: "1700000003.000100")
      reply("brb dinner", ts: "1700000003.000200")
      reply("Then sanded it", ts: "1700000003.000300")
      draft = JournalDraft.last

      press("skip", draft)
      picker = slack.calls_to(:response_url).last[:body]
      boxes = picker["blocks"].find { |block| block["type"] == "input" }["element"]
      assert_equal "checkboxes", boxes["type"]
      assert_equal %w[1700000003.000100 1700000003.000200 1700000003.000300], boxes["options"].pluck("value")
      assert_equal 3, draft.reload.message_count

      reply("one more thing", ts: "1700000003.000400")
      pick(draft, %w[1700000003.000100 1700000003.000300], upto: "1700000003.000300")
      assert_equal [ "Printed the case", "Then sanded it", "one more thing" ], draft.reload.parts.pluck("text"), "unseen replies are kept"
      assert slack.calls_to(:response_url).last[:body]["text"].start_with?("Is this a journal")

      pick(draft, [], upto: "1700000003.000400")
      assert_not JournalDraft.exists?(draft.id)
      assert_equal true, slack.calls_to(:response_url).last[:body]["delete_original"]

      reply("just one", ts: "1700000003.000500")
      press("skip", JournalDraft.last)
      assert_equal 0, JournalDraft.count
    end
  end

  test "photos on their own can go on the last journal" do
    photo = { "id" => "F1", "name" => "case.png", "mimetype" => "image/png", "url_private_download" => "https://files.slack.test/case.png", "size" => 3 }
    with_fake_slack do |slack|
      reply("", files: [ photo ])
      perform_enqueued_jobs(only: JournalPromptJob)
      prompt = slack.calls_to(:chat_postEphemeral).first
      assert_equal({ id: "F1" }, prompt[:blocks].find { |block| block[:type] == "image" }[:slack_file])
      assert_equal %w[journal_draft:attach journal_draft:more journal_draft:skip], prompt[:blocks].find { |block| block[:type] == "actions" }[:elements].pluck(:action_id)

      press("attach", JournalDraft.last)
      download = Faraday::Response.new(status: 200, body: "png", response_headers: { "content-type" => "image/png" })
      stub_method(Faraday, :get, download) { perform_enqueued_jobs(only: CollectSlackJournalJob) }
      assert_equal [ "case.png" ], journals(:first).images.map { |image| image.filename.to_s }
      assert_equal 0, JournalDraft.count
    end
  end

  test "replies by other people, unknown threads and known messages are ignored" do
    with_fake_slack do
      assert_no_difference -> { JournalDraft.count } do
        reply("nice!", user: "U0ADMIN", ts: "1700000004.000100")
        reply("lost", thread_ts: "1699999999.000000", ts: "1700000005.000100")
        reply("dupe", ts: journals(:first).slack_ts)
      end
      assert_no_enqueued_jobs(only: JournalPromptJob)
    end
  end

  test "a web journal echoed back from slack is not collected" do
    projects(:station).journals.create!(user: users(:member), body: "Posted on the site", duration_minutes: 30, source: "web")
    with_fake_slack do
      assert_no_difference -> { JournalDraft.count } do
        reply("Posted on the site", ts: "1700000006.000100")
      end
    end
  end

  test "a top level message in the journals channel is deleted through prometheus" do
    with_fake_slack do |slack|
      deletes = stub_prometheus do
        assert_no_enqueued_jobs { handle_message(user: "U0MEMBER", ts: "1700000007.000100", text: "starting a drone") }
      end
      assert_equal [ "1700000007.000100" ], deletes.map { |body| body["thread_ts"] }
      note = slack.calls_to(:chat_postEphemeral).first
      assert_equal "U0MEMBER", note[:user]
      assert_includes note[:text], "starting a drone"
      assert_includes note[:blocks].last.dig(:elements, 0, :url), "/projects/new"

      slack.calls.clear
      assert_no_enqueued_jobs { handle_message(user: "U0MEMBER", channel: "CELSEWHERE", ts: "1700000008.000100", text: "chat") }
      assert_empty slack.calls
    end
  end

  test "a project anchor posted as the person is kept" do
    with_fake_slack do |slack|
      assert_no_enqueued_jobs { handle_message(user: "U0MEMBER", ts: "1700000009.000100", text: "Drone", bot_id: "B0FALLEN") }
      assert_empty slack.calls
    end
  end

  test "edits and deletions of one reply in a journal update its body" do
    journal = projects(:station).journals.create!(user: users(:member), body: "one\n\ntwo", duration_minutes: 30, source: "slack", slack_channel_id: CHANNEL, slack_ts: "1700000010.000100",
                                                  slack_parts: [ { ts: "1700000010.000100", text: "one" }, { ts: "1700000010.000200", text: "two" } ])
    with_fake_slack do
      SlackBot.handle(:event, { "event" => { "type" => "message", "subtype" => "message_changed", "channel" => CHANNEL, "message" => { "ts" => "1700000010.000200", "text" => "TWO" } } })
      assert_equal "one\n\nTWO", journal.reload.body

      SlackBot.handle(:event, { "event" => { "type" => "message", "subtype" => "message_deleted", "channel" => CHANNEL, "deleted_ts" => "1700000010.000100" } })
      assert_equal "TWO", journal.reload.body
      assert_equal "1700000010.000200", journal.slack_ts
      assert_not journal.discarded?
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

  test "/project points at the site" do
    with_fake_slack do
      response = SlackBot.handle(:command, { "command" => "/project", "user_id" => "U0MEMBER", "channel_id" => CHANNEL })
      assert_includes response[:text], "/projects/new"
    end
  end

  test "the manifest subscribes to channel messages and asks for a user scope" do
    manifest = SlackBot::Manifest.generate(app_url: "https://example.com")
    assert_includes manifest.dig("settings", "event_subscriptions", "bot_events"), "message.channels"
    assert_includes manifest.dig("oauth_config", "scopes", "user"), "chat:write"
    assert_includes manifest.dig("features", "slash_commands").map { |c| c["command"] }, "/project"
  end

  private

  def handle_message(user:, ts:, text:, thread_ts: nil, channel: CHANNEL, files: nil, bot_id: nil)
    event = { "type" => "message", "user" => user, "channel" => channel, "ts" => ts, "text" => text, "thread_ts" => thread_ts, "files" => files, "bot_id" => bot_id }.compact
    SlackBot.handle(:event, { "type" => "event_callback", "event" => event })
  end

  def reply(text, user: "U0MEMBER", ts: "1700000003.000100", thread_ts: projects(:station).slack_thread_ts, files: nil)
    handle_message(user: user, ts: ts, text: text, thread_ts: thread_ts, files: files)
  end

  def press(choice, draft, duration: nil)
    state = { "duration" => { "duration" => { "type" => "plain_text_input", "value" => duration } }, "lapse_url" => { "lapse_url" => { "type" => "plain_text_input", "value" => nil } } }
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => "U0MEMBER" }, "trigger_id" => "t", "response_url" => "https://hooks.slack.test/r",
                                    "state" => { "values" => state }, "actions" => [ { "action_id" => "journal_draft:#{choice}", "value" => draft.public_id } ] })
  end

  def pick(draft, kept, upto:)
    selected = kept.map { |ts| { "value" => ts } }
    state = { "#{SlackMessages::PICKER_INPUT}_0" => { "#{SlackMessages::PICKER_INPUT}_0" => { "type" => "checkboxes", "selected_options" => selected } } }
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => "U0MEMBER" }, "trigger_id" => "t", "response_url" => "https://hooks.slack.test/r",
                                    "state" => { "values" => state }, "actions" => [ { "action_id" => "journal_draft:pick", "value" => "#{draft.public_id}:#{upto}" } ] })
  end

  def stub_prometheus
    deletes = []
    connection = Faraday.new { |f| f.adapter(:test) { |stub| stub.post("/api/v1/threads/delete") { |env| deletes << JSON.parse(env.body); [ 200, {}, '{"ok":true}' ] } } }
    original = Prometheus.method(:connection)
    Prometheus.define_singleton_method(:connection) { connection }
    with_env("PROMETHEUS_API_KEY" => "pk_test") { yield }
    deletes
  ensure
    Prometheus.define_singleton_method(:connection, original)
  end
end
