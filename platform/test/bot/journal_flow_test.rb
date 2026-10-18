require "test_helper"

class JournalFlowTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  CHANNEL = "CJOURNALS"
  PHOTO = { "id" => "F1", "name" => "case.png", "mimetype" => "image/png", "url_private_download" => "https://files.slack.test/case.png", "size" => 3 }.freeze

  test "a thread reply by the owner waits for them to say it is a journal" do
    with_fake_slack do |slack|
      assert_no_difference -> { Journal.count } do
        assert_enqueued_with(job: JournalPromptJob, at: nil) { reply("Printed the case", files: [ PHOTO ]) }
      end
      assert_nil enqueued_jobs.last["scheduled_at"], "the first reply is asked about straight away"
      draft = JournalDraft.last
      assert_equal [ "Printed the case" ], draft.parts.pluck("text")

      perform_enqueued_jobs
      prompt = slack.calls_to(:chat_postEphemeral).first
      assert_equal projects(:station).slack_thread_ts, prompt[:thread_ts]
      assert_equal %w[duration], prompt[:blocks].select { |block| block[:type] == "input" }.pluck(:block_id), "never a box for a Lapse link"
      buttons = prompt[:blocks].find { |block| block[:type] == "actions" }[:elements]
      assert_equal %w[journal_draft:journal journal_draft:more journal_draft:skip], buttons.pluck(:action_id)
      assert_equal [ draft.public_id ], buttons.pluck(:value).uniq
    end
  end

  test "writing without a photo gets a reminder instead of the time box" do
    with_fake_slack do |slack|
      reply("Printed the case")
      perform_enqueued_jobs
      prompt = slack.calls_to(:chat_postEphemeral).last
      assert_includes prompt[:text], "need a photo"
      assert_empty prompt[:blocks].select { |block| block[:type] == "input" }
      assert_equal %w[journal_draft:skip], prompt[:blocks].find { |block| block[:type] == "actions" }[:elements].pluck(:action_id)

      assert_no_difference -> { Journal.count } do
        press("journal", JournalDraft.last, duration: "1h")
      end
      assert_includes slack.calls_to(:response_url).last[:body]["text"], "need a photo"

      reply("", ts: "1700000003.000200", files: [ PHOTO ])
      perform_enqueued_jobs(only: JournalPromptJob)
      assert_equal %w[duration], slack.calls_to(:chat_postEphemeral).last[:blocks].select { |block| block[:type] == "input" }.pluck(:block_id)
    end
  end

  test "several replies become one journal, only with a time and enough photos" do
    with_fake_slack do |slack|
      reply("Printed the case", ts: "1700000003.000100")
      reply("Then sanded it", ts: "1700000003.000200", files: [ PHOTO ])
      perform_enqueued_jobs
      assert_equal 1, slack.calls_to(:chat_postEphemeral).size, "only the last reply's prompt is sent"

      draft = JournalDraft.last
      assert_no_difference -> { Journal.count } do
        press("journal", draft, duration: "")
        press("journal", draft, duration: "ages")
      end
      shown = slack.calls_to(:response_url).last[:body]
      assert_equal "ages", shown["blocks"].find { |block| block["block_id"] == "duration" }.dig("element", "initial_value")
      assert shown["blocks"].any? { |block| block.dig("elements", 0, "text").to_s.include?("should be in hours") }

      assert_no_difference -> { Journal.count } do
        press("journal", draft, duration: "2.25")
      end
      assert slack.calls_to(:response_url).last[:body]["blocks"].any? { |block| block.dig("elements", 0, "text").to_s.include?("Images at least 2 for 2.25h") }

      assert_difference -> { Journal.count }, 1 do
        # An older prompt still showing a box for a Lapse link: whatever is in it is ignored.
        assert_enqueued_with(job: CollectSlackJournalJob) { press("journal", draft, duration: "1.25", lapse_url: "https://example.test/not-lapse") }
      end

      journal = Journal.last
      assert_nil journal.lapse_url
      assert_enqueued_with(job: AddJournalFooterJob, args: [ journal ])
      assert_equal "Printed the case\n\nThen sanded it", journal.body
      assert_equal 75, journal.duration_minutes
      assert_equal 10, journal.xp
      assert_equal "1700000003.000100", journal.slack_ts
      assert_not JournalDraft.exists?(draft.id)
      assert_equal true, slack.calls_to(:response_url).last[:body]["replace_original"]

      download = Faraday::Response.new(status: 200, body: "png", response_headers: { "content-type" => "image/png" })
      stub_method(Faraday, :get, download) { perform_enqueued_jobs }
      assert_equal [ "case.png" ], journal.images.map { |image| image.filename.to_s }
      assert_equal %w[1700000003.000100 1700000003.000200], slack.calls_to(:reactions_add).pluck(:timestamp)
    end
  end

  test "offers the tracked hours, picks timelapses in a modal with thumbnails, and saves the picked ones" do
    user = users(:member)
    user.update!(lapse_token: "lapse-token")
    user.journals.update_all(created_at: 1.day.ago)
    Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", started_at: 1.day.ago)
      .sessions.create!(slack_id: user.slack_id, user: user, joined_at: 61.minutes.ago, left_at: 1.minute.ago, mode: "working")
    desk = lapse_timelapses(:desk)

    with_env("LAPSE_CLIENT_ID" => "svc_test", "LAPSE_CLIENT_SECRET" => "scs_test") do
      with_fake_slack do |slack|
        reply("Soldered the board", files: [ PHOTO ])
        stub_method(LapseTimelapse, :sync, nil) { perform_enqueued_jobs(only: JournalPromptJob) }
        blocks = slack.calls_to(:chat_postEphemeral).last[:blocks]
        duration = blocks.find { |block| block[:block_id] == "duration" }
        assert_equal [ "1", "Time spent (hours)" ], [ duration.dig(:element, :initial_value), duration.dig(:label, :text) ]
        assert duration.dig(:hint, :text).start_with?("(based on tracked recorded hours)")
        pick = button_in(blocks, "Pick timelapses")
        draft = JournalDraft.last

        press_button(pick[:action_id], draft, duration: "1")
        modal = slack.calls_to(:views_open).last[:view]
        assert_equal "lapse_picker", modal[:callback_id]
        row = modal[:blocks].find { |block| block.dig(:text, :text).to_s.include?(desk.name) }
        assert_equal desk.thumbnail_url, row.dig(:accessory, :image_url)

        toggle(modal, button_in(modal[:blocks], "Select"))
        modal = slack.calls_to(:views_update).last[:view]
        assert button_in(modal[:blocks], "Selected ✓")
        assert_equal [ desk.public_id ], JSON.parse(modal[:private_metadata])["selected"]

        assert_enqueued_with(job: RefreshDraftPromptJob, args: [ draft, "1" ]) { submit(modal) }
        assert_equal [ desk.public_id ], draft.reload.timelapse_ids
        stub_method(LapseTimelapse, :sync, nil) { perform_enqueued_jobs(only: RefreshDraftPromptJob) }
        redrawn = slack.calls_to(:response_url).last[:body]["blocks"]
        assert redrawn.any? { |block| block.dig("text", "text").to_s.include?("#{desk.name} · 1.5h") }
        assert_equal "1", redrawn.find { |block| block["block_id"] == "duration" }.dig("element", "initial_value")

        assert_difference -> { Journal.count }, 1 do
          press("journal", draft, duration: "")
        end
        journal = Journal.last
        assert_equal [ 90, 60, false ], [ journal.duration_minutes, journal.tracked_minutes, journal.hours_self_claimed ]
        assert_equal journal, desk.reload.journal
      end
    end
  end

  test "without Lapse connected the prompt offers to connect it, and says when nothing was tracked" do
    with_env("LAPSE_CLIENT_ID" => "svc_test", "LAPSE_CLIENT_SECRET" => "scs_test") do
      with_fake_slack do |slack|
        reply("Soldered the board", files: [ PHOTO ])
        perform_enqueued_jobs(only: JournalPromptJob)
        blocks = slack.calls_to(:chat_postEphemeral).last[:blocks]
        assert_equal %w[duration], blocks.select { |block| block[:type] == "input" }.pluck(:block_id)
        assert_nil blocks.find { |block| block[:block_id] == "duration" }.dig(:element, :initial_value)
        assert blocks.any? { |block| block[:type] == "context" && block.dig(:elements, 0, :text).to_s.start_with?("Nothing tracked") }
        connect = blocks.find { |block| block.dig(:accessory, :text, :text) == "Connect Lapse" }[:accessory]
        assert_includes connect[:url], "/auth/lapse/start?return_to=%2Fsettings%23lapse"

        draft = JournalDraft.last
        press_button(connect[:action_id], draft)
        assert_equal "https://hooks.slack.test/r", draft.reload.prompt_url

        users(:member).update!(lapse_token: "lapse-token")
        stub_method(LapseTimelapse, :sync, nil) { RefreshDraftPromptJob.perform_now(draft) }
        redrawn = slack.calls_to(:response_url).last
        assert_equal [ "https://hooks.slack.test/r", true ], [ redrawn[:url], redrawn[:body]["replace_original"] ]
        assert redrawn[:body]["blocks"].any? { |block| block.dig("accessory", "text", "text") == "Pick timelapses" }
      end
    end
  end

  test "with nothing to pick, check again keeps the typed hours and redraws once Lapse has some" do
    users(:member).update!(lapse_token: "lapse-token")
    lapse_timelapses(:desk).update!(visibility: "PRIVATE")
    with_env("LAPSE_CLIENT_ID" => "svc_test", "LAPSE_CLIENT_SECRET" => "scs_test") do
      with_fake_slack do |slack|
        reply("Soldered the board", files: [ PHOTO ])
        stub_method(LapseTimelapse, :sync, nil) { perform_enqueued_jobs(only: JournalPromptJob) }
        check = slack.calls_to(:chat_postEphemeral).last[:blocks].find { |block| block.dig(:accessory, :text, :text) == "Check again" }
        assert check

        draft = JournalDraft.last
        assert_enqueued_with(job: RefreshDraftPromptJob, args: [ draft, "1.5" ]) { press_button(check[:accessory][:action_id], draft, duration: "1.5") }
        lapse_timelapses(:desk).update!(visibility: "UNLISTED")
        stub_method(LapseTimelapse, :sync, nil) { perform_enqueued_jobs(only: RefreshDraftPromptJob) }
        blocks = slack.calls_to(:response_url).last[:body]["blocks"]
        assert_equal "1.5", blocks.find { |block| block["block_id"] == "duration" }.dig("element", "initial_value")
        assert blocks.any? { |block| block.dig("accessory", "text", "text") == "Pick timelapses" }
      end
    end
  end

  test "the journal that hatches the egg sends a DM and a thread reply to crack it on the site, and only that one" do
    XpEntry.where(user: users(:member)).delete_all
    users(:member).update_columns(xp: 0)
    with_fake_slack do |slack|
      reply("Printed the case", files: [ PHOTO ])
      assert_enqueued_with(job: EggCrackingJob) { press("journal", JournalDraft.last, duration: "1h") }
      stub_method(Faraday, :get, Faraday::Response.new(status: 404)) { perform_enqueued_jobs }

      dm, thread = slack.calls_to(:chat_postMessage).partition { |message| message[:channel] == "U0MEMBER" }.map(&:sole)
      assert_equal [ projects(:station).slack_channel_id, projects(:station).slack_thread_ts ], thread.values_at(:channel, :thread_ts)
      assert_nil dm[:thread_ts]
      [ dm, thread ].each do |message|
        assert_equal ":eyes_shaking: SOMETHING IS CRACKING...", message[:text]
        assert_equal SlackMessages::EGG_TEASERS["lulu"], message[:blocks].find { |block| block[:type] == "image" }[:image_url]
        assert_includes message[:blocks].last.dig(:elements, 0, :url), "/home?hatch=1"
      end

      reply("Then sanded it", ts: "1700000003.000200", files: [ PHOTO ])
      assert_no_enqueued_jobs(only: EggCrackingJob) { press("journal", JournalDraft.last, duration: "1h") }
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
      assert slack.calls_to(:response_url).last[:body]["text"].include?("need a photo")

      pick(draft, [], upto: "1700000003.000400")
      assert_not JournalDraft.exists?(draft.id)
      assert_equal true, slack.calls_to(:response_url).last[:body]["delete_original"]

      reply("just one", ts: "1700000003.000500")
      press("skip", JournalDraft.last)
      assert_equal 0, JournalDraft.count
    end
  end

  test "photos on their own can go on the last journal" do
    with_fake_slack do |slack|
      reply("", files: [ PHOTO ])
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
    projects(:station).journals.create!(user: users(:member), body: "Posted on the site", duration_minutes: 30, source: "web", images: [ photo ])
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
      assert_equal [ "1700000007.000100" ], deletes.map { |body| body["ts"] }
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
    journal = projects(:station).journals.create!(user: users(:member), body: "one\n\ntwo", duration_minutes: 30, source: "slack", slack_channel_id: CHANNEL, slack_ts: "1700000010.000100", images: [ photo ],
                                                  slack_parts: [ { ts: "1700000010.000100", text: "one" }, { ts: "1700000010.000200", text: "two" } ])
    with_fake_slack do
      assert_enqueued_with(job: AddJournalFooterJob, args: [ journal ]) do
        SlackBot.handle(:event, { "event" => { "type" => "message", "subtype" => "message_changed", "channel" => CHANNEL, "message" => { "ts" => "1700000010.000200", "text" => "TWO" } } })
      end
      assert_equal "one\n\nTWO", journal.reload.body

      footed = { "ts" => "1700000010.000200", "text" => "TWO", "blocks" => [ { "type" => "context", "block_id" => SlackMessages::FOOTER_BLOCK_ID, "elements" => [] } ] }
      assert_no_enqueued_jobs(only: AddJournalFooterJob) do
        SlackBot.handle(:event, { "event" => { "type" => "message", "subtype" => "message_changed", "channel" => CHANNEL, "message" => footed } })
      end

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

  def press(choice, draft, duration: nil, lapse_url: nil)
    state = { "duration" => { "duration" => { "type" => "plain_text_input", "value" => duration } }, "lapse_url" => { "lapse_url" => { "type" => "plain_text_input", "value" => lapse_url } } }
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => "U0MEMBER" }, "trigger_id" => "t", "response_url" => "https://hooks.slack.test/r",
                                    "state" => { "values" => state }, "actions" => [ { "action_id" => "journal_draft:#{choice}", "value" => draft.public_id } ] })
  end

  def press_button(action_id, draft, duration: nil)
    state = { "duration" => { "duration" => { "type" => "plain_text_input", "value" => duration } } }
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => "U0MEMBER" }, "trigger_id" => "t", "response_url" => "https://hooks.slack.test/r",
                                    "state" => { "values" => state }, "actions" => [ { "action_id" => action_id, "value" => draft.public_id } ] })
  end

  def button_in(blocks, label)
    blocks.flat_map { |block| [ block[:accessory], *Array(block[:elements]) ] }.compact.find { |element| element[:type] == "button" && element.dig(:text, :text) == label }
  end

  # A button inside the open timelapse picker modal.
  def toggle(modal, button)
    view = { "id" => "V1", "callback_id" => modal[:callback_id], "private_metadata" => modal[:private_metadata] }
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => "U0MEMBER" }, "trigger_id" => "t", "view" => view,
                                    "actions" => [ { "action_id" => button[:action_id], "value" => button[:value] } ] })
  end

  def submit(modal)
    view = { "id" => "V1", "callback_id" => modal[:callback_id], "private_metadata" => modal[:private_metadata], "state" => { "values" => {} } }
    SlackBot.handle(:interaction, { "type" => "view_submission", "user" => { "id" => "U0MEMBER" }, "view" => view })
  end

  def pick(draft, kept, upto:)
    selected = kept.map { |ts| { "value" => ts } }
    state = { "#{SlackMessages::PICKER_INPUT}_0" => { "#{SlackMessages::PICKER_INPUT}_0" => { "type" => "checkboxes", "selected_options" => selected } } }
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => "U0MEMBER" }, "trigger_id" => "t", "response_url" => "https://hooks.slack.test/r",
                                    "state" => { "values" => state }, "actions" => [ { "action_id" => "journal_draft:pick", "value" => "#{draft.public_id}:#{upto}" } ] })
  end

  def stub_prometheus
    deletes = []
    connection = Faraday.new { |f| f.adapter(:test) { |stub| stub.post("/api/v1/messages/delete") { |env| deletes << JSON.parse(env.body); [ 200, {}, '{"ok":true}' ] } } }
    original = Prometheus.method(:connection)
    Prometheus.define_singleton_method(:connection) { connection }
    with_env("PROMETHEUS_API_KEY" => "pk_test") { yield }
    deletes
  ensure
    Prometheus.define_singleton_method(:connection, original)
  end
end
