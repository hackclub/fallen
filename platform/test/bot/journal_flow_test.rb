require "test_helper"

class JournalFlowTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  CHANNEL = "CJOURNALS"
  # Enough writing for a journal (Journal::MIN_BODY_LENGTH).
  WRITTEN = "Printed the case, sanded the edges smooth and test fitted the board. The lid was tight so I filed the clips."
  PHOTO = { "id" => "F1", "name" => "case.png", "mimetype" => "image/png", "url_private_download" => "https://files.slack.com/case.png", "size" => 3 }.freeze

  test "a thread reply by the owner waits for them to say it is a journal" do
    with_fake_slack do |slack|
      assert_no_difference -> { Journal.count } do
        assert_enqueued_with(job: JournalPromptJob, at: nil) { reply(WRITTEN, files: [ PHOTO ]) }
      end
      assert_nil enqueued_jobs.last["scheduled_at"], "the first reply is asked about straight away"
      draft = JournalDraft.last
      assert_equal [ WRITTEN ], draft.parts.pluck("text")

      perform_enqueued_jobs
      prompt = slack.calls_to(:chat_postEphemeral).first
      assert_equal projects(:station).slack_thread_ts, prompt[:thread_ts]
      assert_equal %w[duration], prompt[:blocks].select { |block| block[:type] == "input" }.pluck(:block_id), "never a box for a Lapse link"
      buttons = prompt[:blocks].find { |block| block[:type] == "actions" }[:elements]
      assert_equal %w[journal_draft:journal journal_draft:more journal_draft:skip], buttons.pluck(:action_id)
      assert_equal [ draft.public_id ], buttons.pluck(:value).uniq
    end
  end

  test "a teammate's thread reply becomes their own draft, anyone else's is chat" do
    with_fake_slack do
      projects(:station).memberships.create!(user: users(:admin))
      reply(WRITTEN, user: "U0ADMIN", files: [ PHOTO ])
      assert_equal users(:admin), JournalDraft.last.user

      projects(:station).memberships.destroy_all
      assert_no_difference -> { JournalDraft.count } do
        reply(WRITTEN, user: "U0ADMIN", ts: "1700000009.000100", files: [ PHOTO ])
      end
    end
  end

  test "writing without a photo gets a reminder instead of the time box" do
    with_fake_slack do |slack|
      reply(WRITTEN)
      perform_enqueued_jobs
      prompt = slack.calls_to(:chat_postEphemeral).last
      assert_equal "Nice! Please also add a photo for your journal.", prompt[:text]
      assert prompt[:blocks].first.dig(:text, :text).start_with?("Nice! Please also add a photo for your journal :>> you can just send a message with the photo!")
      assert_empty prompt[:blocks].select { |block| block[:type] == "input" }
      assert_equal %w[journal_draft:skip], prompt[:blocks].find { |block| block[:type] == "actions" }[:elements].pluck(:action_id)

      assert_no_difference -> { Journal.count } do
        press("journal", JournalDraft.last, duration: "1h")
      end
      assert_includes slack.calls_to(:response_url).last[:body]["text"], "add a photo"

      reply("", ts: "1700000003.000200", files: [ PHOTO ])
      perform_enqueued_jobs(only: JournalPromptJob)
      assert_equal %w[duration], slack.calls_to(:chat_postEphemeral).last[:blocks].select { |block| block[:type] == "input" }.pluck(:block_id)
    end
  end

  test "too little writing gets a reminder to write more, with the photo too when there is none" do
    with_fake_slack do |slack|
      reply("Printed the case", files: [ PHOTO ])
      perform_enqueued_jobs
      prompt = slack.calls_to(:chat_postEphemeral).last
      assert prompt[:blocks].first.dig(:text, :text).start_with?("Nice! Please write a bit more about what you did, at least 100 characters so a reviewer can follow what you did (you're at 16) :>>")
      assert_empty prompt[:blocks].select { |block| block[:type] == "input" }

      reply("Short again", ts: "1700000004.000100", thread_ts: projects(:station).slack_thread_ts)
      JournalDraft.last.update!(parts: [ { "ts" => "1700000004.000100", "text" => "Short again" } ])
      perform_enqueued_jobs
      assert_includes slack.calls_to(:chat_postEphemeral).last[:blocks].first.dig(:text, :text), "and add a photo for your journal"

      assert_no_difference -> { Journal.count } do
        press("journal", JournalDraft.last, duration: "1")
      end
    end
  end

  test "the photo reminder asks for one photo per two hours tracked" do
    users(:member).journals.update_all(created_at: 1.day.ago)
    users(:member).timer_sessions.create!(started_at: 150.minutes.ago, stopped_at: Time.current)
    with_fake_slack do |slack|
      reply(WRITTEN)
      perform_enqueued_jobs
      assert slack.calls_to(:chat_postEphemeral).last[:blocks].first.dig(:text, :text).start_with?("Nice! Please also add 2 photos for your journal :>> you can just send a message with the photos!")
    end
  end

  test "several replies become one journal, only with a time and enough photos" do
    with_fake_slack do |slack|
      reply(WRITTEN, ts: "1700000003.000100")
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
      assert_equal "#{WRITTEN}\n\nThen sanded it", journal.body
      assert_equal 75, journal.duration_minutes
      assert_equal 10, journal.xp
      assert_equal "1700000003.000100", journal.slack_ts
      assert_not JournalDraft.exists?(draft.id)
      assert_equal true, slack.calls_to(:response_url).last[:body]["replace_original"]

      download = Faraday::Response.new(status: 200, body: "png", response_headers: { "content-type" => "image/png" })
      stub_method(Faraday, :get, download) { perform_enqueued_jobs }
      assert_equal [ "case.png" ], journal.images.map { |image| image.filename.to_s }
      assert_empty slack.calls_to(:reactions_add), "no reaction on the saved replies"
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
        reply(WRITTEN, files: [ PHOTO ])
        stub_method(LapseTimelapse, :sync, nil) { perform_enqueued_jobs(only: JournalPromptJob) }
        blocks = slack.calls_to(:chat_postEphemeral).last[:blocks]
        duration = blocks.find { |block| block[:block_id] == "duration" }
        assert_equal [ "1", "Time spent (hours)" ], [ duration.dig(:element, :initial_value), duration.dig(:label, :text) ]
        assert duration.dig(:hint, :text).start_with?("(based on tracked recorded hours)")
        pick = button_in(blocks, "Pick timelapses")
        draft = JournalDraft.last

        press_button(pick[:action_id], draft, duration: "1")
        modal = slack.calls_to(:views_open).last[:view]
        assert_equal [ "lapse_picker", "Timelapses Selection" ], [ modal[:callback_id], modal.dig(:title, :text) ]
        assert modal[:blocks].first.dig(:elements, 0, :text).start_with?("Powered by :lapse: Lapse")
        row = modal[:blocks].find { |block| block.dig(:text, :text).to_s.include?(desk.name) }
        assert_equal desk.thumbnail_url, row.dig(:accessory, :image_url)
        assert modal[:blocks].any? { |block| block[:block_id] == "lapse_pick_#{desk.public_id}" && block.dig(:elements, 0, :type) == "checkboxes" }

        assert_enqueued_with(job: RefreshDraftPromptJob, args: [ draft, "1" ]) { submit(modal, ticked: [ desk ]) }
        assert_equal [ desk.public_id ], draft.reload.timelapse_ids
        stub_method(LapseTimelapse, :sync, nil) { perform_enqueued_jobs(only: RefreshDraftPromptJob) }
        assert_equal({ "delete_original" => true }, slack.calls_to(:response_url).last[:body])
        redrawn = slack.calls_to(:chat_postEphemeral).last
        assert_equal projects(:station).slack_thread_ts, redrawn[:thread_ts], "the new prompt goes in the thread, never the channel"
        assert redrawn[:blocks].any? { |block| block.dig(:text, :text).to_s.include?("#{desk.name} · 1.5h") }
        assert_equal "1", redrawn[:blocks].find { |block| block[:block_id] == "duration" }.dig(:element, :initial_value)
        assert modal[:blocks].any? { |block| block[:type] == "divider" }

        assert_difference -> { Journal.count }, 1 do
          press("journal", draft, duration: "")
        end
        journal = Journal.last
        assert_equal [ 90, 60, false ], [ journal.duration_minutes, journal.tracked_minutes, journal.hours_self_claimed ]
        assert_equal journal, desk.reload.journal
      end
    end
  end

  test "the picker pages through every timelapse, keeps ticks across pages, and shows used ones without a box" do
    user = users(:member)
    user.update!(lapse_token: "lapse-token")
    older = 25.times.map { |i| user.lapse_timelapses.create!(lapse_id: "lapse_#{i}", name: "Session #{i}", duration_seconds: 600, visibility: "UNLISTED", playback_url: "https://cdn.lapse.test/#{i}.mp4", recorded_at: (i + 2).days.ago) }
    used = projects(:station).journals.create!(user: user, body: journal_text("x"), duration: "1", images: [ photo ])
    older.first.update!(journal: used)
    draft = JournalDraft.create!(project: projects(:station), user: user, parts: [ { "ts" => "1700000003.000100", "text" => "x" } ])

    with_env("LAPSE_CLIENT_ID" => "svc_test", "LAPSE_CLIENT_SECRET" => "scs_test") do
      with_fake_slack do |slack|
        press_button("journal_draft:pick_lapse", draft)
        first = slack.calls_to(:views_open).last[:view]
        assert_equal 20, first[:blocks].count { |block| block[:type] == "section" }
        on_journal = first[:blocks].find { |block| block.dig(:text, :text).to_s.include?("On your <") }
        assert_includes on_journal.dig(:text, :text), "/projects/#{projects(:station).to_param}#journal-#{used.public_id}|journal from "
        assert_not first[:blocks].any? { |block| block[:block_id] == "lapse_pick_#{older.first.public_id}" }, "a used one has no box"

        toggle(first, button_in(first[:blocks], "Older ›"), ticked: [ lapse_timelapses(:desk), older[1] ])
        second = slack.calls_to(:views_update).last[:view]
        assert_includes second[:blocks].map { |block| block.dig(:elements, 0, :text) }, "Page 2 of 2"
        assert button_in(second[:blocks], "‹ Newer")

        submit(second, ticked: [ older.last ])
        assert_equal [ lapse_timelapses(:desk), older[1], older.last ].map(&:public_id).sort, draft.reload.timelapse_ids.sort
      end
    end
  end

  test "ticking more than a journal takes says so instead of saving" do
    user = users(:member)
    user.update!(lapse_token: "lapse-token")
    many = 11.times.map { |i| user.lapse_timelapses.create!(lapse_id: "lapse_#{i}", name: "Session #{i}", duration_seconds: 600, visibility: "UNLISTED", playback_url: "https://cdn.lapse.test/#{i}.mp4") }
    draft = JournalDraft.create!(project: projects(:station), user: user, parts: [ { "ts" => "1700000003.000100", "text" => "x" } ])
    with_fake_slack do |slack|
      press_button("journal_draft:pick_lapse", draft)
      response = submit(slack.calls_to(:views_open).last[:view], ticked: many)
      assert_equal "update", response[:response_action]
      assert response[:view][:blocks].any? { |block| block.dig(:elements, 0, :text).to_s.include?("A journal takes up to 10") }
      assert_empty draft.reload.timelapse_ids
    end
  end

  test "without Lapse connected the prompt offers to connect it, and says when nothing was tracked" do
    with_env("LAPSE_CLIENT_ID" => "svc_test", "LAPSE_CLIENT_SECRET" => "scs_test") do
      with_fake_slack do |slack|
        reply(WRITTEN, files: [ PHOTO ])
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
        assert_equal [ "https://hooks.slack.test/r", { "delete_original" => true } ], slack.calls_to(:response_url).last.values_at(:url, :body)
        redrawn = slack.calls_to(:chat_postEphemeral).last
        assert_equal projects(:station).slack_thread_ts, redrawn[:thread_ts]
        assert redrawn[:blocks].any? { |block| block.dig(:accessory, :text, :text) == "Pick timelapses" }
        assert_nil draft.reload.prompt_url
      end
    end
  end

  test "with nothing to pick, check again keeps the typed hours and redraws once Lapse has some" do
    users(:member).update!(lapse_token: "lapse-token")
    playback = lapse_timelapses(:desk).playback_url
    lapse_timelapses(:desk).update!(playback_url: nil)
    lapse_timelapses(:hidden).update!(playback_url: nil)
    with_env("LAPSE_CLIENT_ID" => "svc_test", "LAPSE_CLIENT_SECRET" => "scs_test") do
      with_fake_slack do |slack|
        reply(WRITTEN, files: [ PHOTO ])
        stub_method(LapseTimelapse, :sync, nil) { perform_enqueued_jobs(only: JournalPromptJob) }
        check = slack.calls_to(:chat_postEphemeral).last[:blocks].find { |block| block.dig(:accessory, :text, :text) == "Check again" }
        assert check

        draft = JournalDraft.last
        assert_enqueued_with(job: RefreshDraftPromptJob, args: [ draft, "1.5" ]) { press_button(check[:accessory][:action_id], draft, duration: "1.5") }
        lapse_timelapses(:desk).update!(playback_url: playback)
        stub_method(LapseTimelapse, :sync, nil) { perform_enqueued_jobs(only: RefreshDraftPromptJob) }
        blocks = slack.calls_to(:chat_postEphemeral).last[:blocks]
        assert_equal "1.5", blocks.find { |block| block[:block_id] == "duration" }.dig(:element, :initial_value)
        assert blocks.any? { |block| block.dig(:accessory, :text, :text) == "Pick timelapses" }
      end
    end
  end

  test "the journal that hatches the egg sends a DM and a thread reply to crack it on the site, and only that one" do
    XpEntry.where(user: users(:member)).delete_all
    users(:member).update_columns(xp: 0)
    with_fake_slack do |slack|
      reply(WRITTEN, files: [ PHOTO ])
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
      reply(WRITTEN)
      press("more", JournalDraft.last)
      assert_includes slack.calls_to(:response_url).last[:body]["text"], "Keep going"
      reply("and sanded it", ts: "1700000003.000200")
      assert_equal 2, JournalDraft.last.message_count
    end
  end

  test "a later reply waits for a pause before asking again" do
    with_fake_slack do
      reply(WRITTEN)
      assert_enqueued_with(job: JournalPromptJob, at: JournalDraft::ASK_AFTER.from_now) { reply("Then sanded it", ts: "1700000003.000200") }
    end
  end

  test "not a journal on one message drops it, on several lets the person tick which belong" do
    with_fake_slack do |slack|
      reply(WRITTEN, ts: "1700000003.000100")
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
      assert_equal [ WRITTEN, "Then sanded it", "one more thing" ], draft.reload.parts.pluck("text"), "unseen replies are kept"
      assert slack.calls_to(:response_url).last[:body]["text"].include?("add a photo")

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
    projects(:station).journals.create!(user: users(:member), body: journal_text("Posted on the site"), duration_minutes: 30, source: "web", images: [ photo ])
    with_fake_slack do
      assert_no_difference -> { JournalDraft.count } do
        reply(journal_text("Posted on the site"), ts: "1700000006.000100")
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
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text("one\n\ntwo"), duration_minutes: 30, source: "slack", slack_channel_id: CHANNEL, slack_ts: "1700000010.000100", images: [ photo ],
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

  test "fallen's own rewrite of a web journal does not come back as an edit" do
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text("**Soldered** the board\n![board.png](/rails/active_storage/blobs/redirect/x/board.png)"),
                                                  duration_minutes: 60, source: "web", images: [ photo ], slack_channel_id: CHANNEL, slack_ts: "1700000020.000100")
    with_fake_slack do
      SlackBot.handle(:event, { "event" => { "type" => "message", "subtype" => "message_changed", "channel" => CHANNEL,
                                              "message" => { "ts" => journal.slack_ts, "text" => SlackMessages.journal(journal)[:text].tr("\n", " "), "user" => "U0MEMBER" } } })
      assert_includes journal.reload.body, "**Soldered**"

      SlackBot.handle(:event, { "event" => { "type" => "message", "subtype" => "message_changed", "channel" => CHANNEL,
                                              "message" => { "ts" => journal.slack_ts, "text" => journal_text("Soldered it twice"), "user" => "U0MEMBER" } } })
      assert_equal journal_text("Soldered it twice"), journal.reload.body
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

  # A button inside the open timelapse picker modal, with these timelapses' boxes ticked on the page shown.
  def toggle(modal, button, ticked: [])
    view = { "id" => "V1", "callback_id" => modal[:callback_id], "private_metadata" => modal[:private_metadata], "state" => { "values" => ticks(ticked) } }
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => "U0MEMBER" }, "trigger_id" => "t", "view" => view,
                                    "actions" => [ { "action_id" => button[:action_id], "value" => button[:value] } ] })
  end

  def submit(modal, ticked: [])
    view = { "id" => "V1", "callback_id" => modal[:callback_id], "private_metadata" => modal[:private_metadata], "state" => { "values" => ticks(ticked) } }
    SlackBot.handle(:interaction, { "type" => "view_submission", "user" => { "id" => "U0MEMBER" }, "view" => view })
  end

  def ticks(timelapses)
    timelapses.to_h do |timelapse|
      [ "#{LapsePicker::CHECKBOX_BLOCK}#{timelapse.public_id}", { "lapse_picker:tick" => { "type" => "checkboxes", "selected_options" => [ { "value" => timelapse.public_id } ] } } ]
    end
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
