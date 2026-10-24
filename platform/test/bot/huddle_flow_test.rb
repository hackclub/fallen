require "test_helper"

class HuddleFlowTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @huddle = Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", thread_ts: "1700000000.000100", started_at: 1.hour.ago)
    @session = @huddle.sessions.create!(slack_id: "U0MEMBER", user: users(:member), joined_at: 5.minutes.ago)
  end

  test "asks privately in the huddle's thread, as their pet" do
    with_fake_slack do |slack|
      HuddlePromptJob.perform_now(@session)

      prompt = slack.calls_to(:chat_postEphemeral).sole
      assert_equal [ "CHUDDLE", "U0MEMBER", "1700000000.000100" ], prompt.values_at(:channel, :user, :thread_ts)
      assert_equal "Lulu", prompt[:username]
      assert_equal SlackMessages::PET_PFPS["lulu"], prompt[:icon_url]
      assert_equal "<@U0MEMBER> what are you working on today?", prompt[:blocks].first[:text][:text]
      assert_equal %w[huddle_goal:commit huddle_goal:chill], prompt[:blocks].last[:elements].pluck(:action_id), "someone with a project gets no sign-up nudge"
    end
  end

  test "someone without a pet hears from the bot" do
    session = @huddle.sessions.create!(slack_id: "U0STRANGER", joined_at: 1.minute.ago)
    with_fake_slack do |slack|
      HuddlePromptJob.perform_now(session)
      prompt = slack.calls_to(:chat_postEphemeral).sole
      assert_nil prompt[:username]
      assert_equal "Sign up for Fallen", prompt[:blocks].last[:elements].sole[:text][:text]
    end
  end

  test "someone with an account but no project is pointed at starting one" do
    users(:member).projects.update_all(discarded_at: Time.current)
    with_fake_slack do |slack|
      HuddlePromptJob.perform_now(@session)
      assert_equal "Start a project", slack.calls_to(:chat_postEphemeral).sole[:blocks].last[:elements].sole[:text][:text]
    end
  end

  test "huddle visits from before signing up become theirs once their Slack is linked" do
    visit = @huddle.sessions.create!(slack_id: "U0NEWBIE", joined_at: 1.minute.ago)
    users(:newcomer).update!(slack_id: "U0NEWBIE")
    assert_equal users(:newcomer), visit.reload.user
  end

  test "signing up while in the huddle gets a welcome there and in a DM" do
    @huddle.sessions.create!(slack_id: "U0NEWBIE", joined_at: 1.minute.ago)
    users(:newcomer).update_column(:created_at, 30.seconds.ago)
    users(:newcomer).update!(slack_id: "U0NEWBIE")
    assert_no_enqueued_jobs(only: HuddleWelcomeJob) { users(:newcomer).update!(display_name: "Newbie") }

    with_fake_slack do |slack|
      assert_enqueued_with(job: HuddleWelcomeJob) { users(:newcomer).update!(pet: "sami") }
      perform_enqueued_jobs(only: HuddleWelcomeJob)

      thread, dm = slack.calls_to(:chat_postMessage)
      assert_equal [ "CHUDDLE", "1700000000.000100", "Sami" ], thread.values_at(:channel, :thread_ts, :username)
      assert_match "<@U0NEWBIE> just joined Fallen", thread[:text]
      assert_equal "U0NEWBIE", dm[:channel]
      assert_equal "Start a project", dm[:blocks].last[:elements].sole[:text][:text]
    end
  end

  test "an account from before this visit gets only the DM" do
    @huddle.sessions.create!(slack_id: "U0NEWBIE", joined_at: 1.minute.ago)
    users(:newcomer).update_column(:created_at, 1.day.ago)
    with_fake_slack do |slack|
      users(:newcomer).update!(slack_id: "U0NEWBIE", pet: "lulu")
      perform_enqueued_jobs(only: HuddleWelcomeJob)
      assert_equal [ "U0NEWBIE" ], slack.calls_to(:chat_postMessage).pluck(:channel)
    end
  end

  test "no welcome for someone who is not in the huddle" do
    with_fake_slack do |slack|
      users(:newcomer).update!(slack_id: "U0NEWBIE", pet: "lulu")
      perform_enqueued_jobs(only: HuddleWelcomeJob)
      assert_empty slack.calls_to(:chat_postMessage)
    end
  end

  test "commit stores the goal on that session and the one they have open now" do
    earlier = @huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 50.minutes.ago, left_at: 40.minutes.ago, mode: "chilling")
    @session.update!(joined_at: 10.minutes.ago, left_at: 6.minutes.ago)
    now = @huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 5.minutes.ago)
    with_fake_slack do |slack|
      press("commit", goal: "  Soldering the  keyboard ")

      assert_equal [ [ "working", "Soldering the keyboard" ] ], [ @session.reload, now.reload ].map { |s| [ s.mode, s.goal ] }.uniq
      assert_equal "chilling", earlier.reload.mode
      assert_match "Soldering the keyboard", slack.calls_to(:response_url).sole[:body]["text"]

      perform_enqueued_jobs
      post = slack.calls_to(:chat_postMessage).sole
      assert_equal [ "CHUDDLE", "1700000000.000100", "Lulu" ], post.values_at(:channel, :thread_ts, :username)
      assert_equal "<@U0MEMBER> is working on Soldering the keyboard today!!", post[:text]
    end
  end

  test "someone who has not answered is asked again every ten messages in the thread" do
    @session.update!(prompted_at_count: 0)
    answered = @huddle.sessions.create!(slack_id: "U0ADMIN", joined_at: 5.minutes.ago, prompted_at_count: 0, mode: "chilling")
    with_fake_slack do
      9.times { |i| post_in_thread("1700000100.#{i.to_s.rjust(6, '0')}") }
      assert_no_enqueued_jobs only: HuddlePromptJob

      assert_enqueued_with(job: HuddlePromptJob, args: [ @session ]) { post_in_thread("1700000100.000010") }
      assert_equal 10, @session.reload.prompted_at_count
      assert_equal 0, answered.reload.prompted_at_count
      assert_no_difference -> { JournalDraft.count } do
        assert_no_enqueued_jobs(only: HuddlePromptJob) { post_in_thread("1700000100.000011") }
      end
    end
  end

  test "commit with nothing typed asks again" do
    with_fake_slack do |slack|
      press("commit", goal: " ")

      assert_nil @session.reload.mode
      assert_includes slack.calls_to(:response_url).sole[:body]["blocks"].to_s, "Write what you're working on first!"
    end
  end

  test "chilling is stored too" do
    with_fake_slack do
      press("chill")
      assert_equal "chilling", @session.reload.mode
    end
  end

  test "coming back with a goal asks whether they are still on it" do
    @session.update!(goal: "Case")
    with_fake_slack do |slack|
      HuddlePromptJob.perform_now(@session)

      prompt = slack.calls_to(:chat_postEphemeral).sole
      assert_equal "<@U0MEMBER> are you still working on Case?", prompt[:text]
      assert_equal %w[yes other chill], prompt[:blocks][1][:elements].sole[:options].map { |option| option[:value] }
      assert_equal "huddle_goal:still", prompt[:blocks].last[:elements].sole[:action_id]
      assert_not prompt[:blocks].any? { |block| block[:type] == "input" }, "the box only shows for something else"
    end
  end

  test "picking something else shows the box, picking anything else hides it" do
    @session.update!(goal: "Case")
    with_fake_slack do |slack|
      pick("other")
      blocks = slack.calls_to(:response_url).last[:body]["blocks"]
      assert_equal [ "goal" ], blocks.select { |block| block["type"] == "input" }.pluck("block_id")
      assert_equal "other", blocks[1]["elements"].sole["initial_option"]["value"]
      assert_equal "#{@session.public_id}:other", blocks.last["elements"].sole["value"]

      pick("yes")
      assert_empty slack.calls_to(:response_url).last[:body]["blocks"].select { |block| block["type"] == "input" }
    end
  end

  test "still on it keeps the goal without announcing it again" do
    @session.update!(goal: "Case")
    with_fake_slack do |slack|
      press("still", still: "yes")
      assert_equal [ "working", "Case" ], [ @session.reload.mode, @session.goal ]
      assert_no_enqueued_jobs only: HuddleCommitJob
    end
  end

  test "working on something else needs it written and announces it" do
    @session.update!(goal: "Case")
    with_fake_slack do |slack|
      press("still", still: "other", goal: "")
      assert_nil @session.reload.mode
      assert_includes slack.calls_to(:response_url).last[:body]["blocks"].to_s, "Write what you're working on first!"

      assert_enqueued_with(job: HuddleCommitJob) { press("still", still: "other", goal: "Firmware") }
      assert_equal [ "working", "Firmware" ], [ @session.reload.mode, @session.goal ]
    end
  end

  test "still prompt: chilling, or nothing picked" do
    @session.update!(goal: "Case")
    with_fake_slack do |slack|
      press("still")
      assert_includes slack.calls_to(:response_url).last[:body]["blocks"].to_s, "Pick one!"

      press("still", still: "chill")
      assert_equal [ "chilling", nil ], [ @session.reload.mode, @session.goal ]
    end
  end

  test "only the person asked can answer" do
    with_fake_slack do
      press("chill", user: "U0ADMIN")
      assert_nil @session.reload.mode
    end
  end

  test "the handoff mentions everyone with a link to the huddle and rings them in" do
    browser = FakeBrowserClient.new("rooms.notifyMember" => ->(fields) { fields[:user_id] == "U0STRANGER" ? SlackBot::BrowserClient::Error.new("rooms.notifyMember", "user_not_found") : { "ok" => true } })
    SlackHuddle.instance_variable_set(:@client, browser)
    with_fake_slack do |slack|
      with_env("SLACK_HUDDLE_CHANNEL_ID" => "CHUDDLE", "SLACK_BROWSER_TOKEN" => "xoxc-test", "SLACK_BROWSER_COOKIE" => "xoxd-test") do
        perform_enqueued_jobs(only: HuddleRingJob) { HuddleHandoffJob.perform_now(@huddle, %w[U0MEMBER U0STRANGER]) }
      end
      assert_equal [ { channel_id: "CHUDDLE", user_id: "U0MEMBER" }, { channel_id: "CHUDDLE", user_id: "U0STRANGER" } ],
                   browser.calls.map { |_, fields| fields.slice(:channel_id, :user_id) }

      post = slack.calls_to(:chat_postMessage).sole
      assert_equal [ "CHUDDLE", "1700000000.000100" ], post.values_at(:channel, :thread_ts)
      assert_match "<@U0MEMBER> <@U0STRANGER>", post[:text]
      assert_equal "https://hackclub.slack.com/archives/CHUDDLE/p1700000000000100", post[:blocks].last[:elements].sole[:url]
    end
  ensure
    SlackHuddle.reset!
  end

  test "on joining the question also goes to their DMs, which follow an answer given in the thread" do
    with_fake_slack do |slack|
      HuddlePromptJob.perform_now(@session, dm: true)

      assert_equal 1, slack.calls_to(:chat_postEphemeral).size
      dm = slack.calls_to(:chat_postMessage).sole
      assert_equal [ "U0MEMBER", "Lulu" ], dm.values_at(:channel, :username)
      assert_equal "huddle_goal:commit", dm[:blocks].last[:elements].first[:action_id]
      assert_equal [ "U0MEMBER", "1700009999.000001" ], [ @session.reload.dm_channel_id, @session.prompt_dm_ts ]

      press("commit", goal: "Case", channel: "CHUDDLE")
      perform_enqueued_jobs(only: HuddleDmAnswerJob)
      update = slack.calls_to(:chat_update).sole
      assert_equal [ "U0MEMBER", "1700009999.000001" ], update.values_at(:channel, :ts)
      assert_match "Working on: Case", update[:text]
    end
  end

  test "answering both the DM and the thread announces once" do
    with_fake_slack do
      assert_enqueued_with(job: HuddleCommitJob) { press("commit", goal: "Case", channel: "U0MEMBER") }
      assert_no_enqueued_jobs(only: HuddleCommitJob) { press("commit", goal: "Case firmware", channel: "CHUDDLE") }
      assert_equal "Case firmware", @session.reload.goal
    end
  end

  test "answering in the DM does not update it twice" do
    @session.update!(dm_channel_id: "U0MEMBER", prompt_dm_ts: "1700009999.000001")
    with_fake_slack do
      assert_no_enqueued_jobs(only: HuddleDmAnswerJob) { press("chill", channel: "U0MEMBER") }
    end
  end

  test "reprompts in the thread do not DM again" do
    with_fake_slack do |slack|
      HuddlePromptJob.perform_now(@session)
      assert_empty slack.calls_to(:chat_postMessage)
    end
  end

  test "leaving asks what they got done a little later" do
    assert_enqueued_with(job: HuddleWrapUpJob, args: [ @session ]) { @session.leave!(Time.current, "sync") }
  end

  test "the wrap-up DM asks what they got done on their goal" do
    @session.update!(joined_at: 1.hour.ago, left_at: 2.minutes.ago, mode: "working", goal: "Case")
    with_fake_slack do |slack|
      HuddleWrapUpJob.perform_now(@session)

      dm = slack.calls_to(:chat_postMessage).sole
      assert_equal [ "U0MEMBER", "Lulu" ], dm.values_at(:channel, :username)
      assert_equal "Thanks for hanging out! You were working on Case. What did you get done?", dm[:text]
      assert_equal [ [ "huddle_done:share", "save" ] ], dm[:blocks].last[:elements].map { |button| [ button[:action_id], button[:text][:text] ] }
      assert_not_nil @session.reload.wrap_up_asked_at

      HuddleWrapUpJob.perform_now(@session)
      assert_equal 1, slack.calls_to(:chat_postMessage).size, "asked once"
    end
  end

  test "no wrap-up for a short visit, chilling, coming back, or Slack ending the huddle" do
    with_fake_slack do |slack|
      @session.update!(left_at: 2.minutes.ago)
      HuddleWrapUpJob.perform_now(@session)

      @session.update!(joined_at: 1.hour.ago, mode: "chilling")
      HuddleWrapUpJob.perform_now(@session)

      @session.update!(mode: nil)
      back = @huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 1.minute.ago)
      HuddleWrapUpJob.perform_now(@session)

      back.destroy!
      @huddle.update!(ended_at: @session.left_at + 10.seconds)
      HuddleWrapUpJob.perform_now(@session)

      assert_empty slack.calls_to(:chat_postMessage)
    end
  end

  test "a visit split by dropped connections counts as one" do
    @huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 20.minutes.ago, left_at: 6.minutes.ago)
    @session.update!(left_at: 2.minutes.ago)
    with_fake_slack do |slack|
      HuddleWrapUpJob.perform_now(@session)
      assert_equal 1, slack.calls_to(:chat_postMessage).size
    end
  end

  test "sharing what they got done stores it and tells the huddle" do
    @session.update!(left_at: 2.minutes.ago)
    with_fake_slack do |slack|
      press_done("share", done: " ")
      assert_includes slack.calls_to(:response_url).last[:body]["blocks"].to_s, "Write what you got done first!"

      press_done("share", done: "Wired the matrix\n")
      assert_equal "Wired the matrix", @session.reload.done
      assert_match "You got done: Wired the matrix", slack.calls_to(:response_url).last[:body]["text"]

      perform_enqueued_jobs(only: HuddleDoneJob)
      post = slack.calls_to(:chat_postMessage).sole
      assert_equal [ "CHUDDLE", "1700000000.000100", "Lulu" ], post.values_at(:channel, :thread_ts, :username)
      assert_equal "<@U0MEMBER> got this done in the huddle: Wired the matrix :tada:", post[:text]
    end
  end

  test "the wrap-up asks how many of the counted hours were work, less pauses, and keeps the difference" do
    freeze_time do
      @session.update!(joined_at: 50.minutes.ago, left_at: 2.minutes.ago, mode: "working")
      users(:member).huddle_pauses.create!(started_at: 40.minutes.ago, ended_at: 20.minutes.ago, end_reason: "resumed")
      with_fake_slack do |slack|
        HuddleWrapUpJob.perform_now(@session)
        hours = slack.calls_to(:chat_postMessage).sole[:blocks].find { |block| block[:block_id] == "hours" }
        assert_equal [ "0.47", "0.25", "0" ], hours[:element][:options].pluck(:value)
        assert_equal "0.47", hours[:element][:initial_option][:value]

        press_done("share", done: "Wired it", hours: "1")
        assert_includes slack.calls_to(:response_url).last[:body]["blocks"].to_s, "Pick how many hours you were working"
        assert_equal 0, @session.reload.deducted_seconds

        press_done("share", done: "Wired it", hours: "0.25")
        assert_equal 13.minutes.to_i, @session.reload.deducted_seconds
      end
    end
  end

  test "fewer honest hours come off the newest sessions of the visit first" do
    freeze_time do
      earlier = @huddle.sessions.create!(slack_id: "U0MEMBER", user: users(:member), joined_at: 50.minutes.ago, left_at: 30.minutes.ago, mode: "working")
      @session.update!(joined_at: 25.minutes.ago, left_at: 15.minutes.ago, mode: "working")
      with_fake_slack do
        HuddleWrapUpJob.perform_now(@session)
        press_done("share", done: "Wired it", hours: "0.25")
      end
      assert_equal [ 5.minutes.to_i, 10.minutes.to_i ], [ earlier.reload.deducted_seconds, @session.reload.deducted_seconds ]
    end
  end

  test "skip on a DM from before skipping was taken out stores nothing" do
    with_fake_slack do |slack|
      assert_no_enqueued_jobs(only: HuddleDoneJob) { press_done("skip") }
      assert_nil @session.reload.done
      assert_equal "No worries, see you next time!", slack.calls_to(:response_url).sole[:body]["text"]
    end
  end

  private

  def post_in_thread(ts)
    SlackBot.handle(:event, { "type" => "event_callback", "event" => { "type" => "message", "channel" => "CHUDDLE", "user" => "U0MEMBER", "text" => "hi", "ts" => ts, "thread_ts" => @huddle.thread_ts } })
  end

  def press(choice, goal: nil, still: nil, user: "U0MEMBER", channel: "CHUDDLE")
    state = { "goal" => { "goal" => { "type" => "plain_text_input", "value" => goal } } }
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => user }, "channel" => { "id" => channel }, "trigger_id" => "t", "response_url" => "https://hooks.slack.test/r",
                                    "state" => { "values" => state }, "actions" => [ { "action_id" => "huddle_goal:#{choice}", "value" => [ @session.public_id, still ].compact.join(":") } ] })
  end

  def press_done(choice, done: nil, hours: nil)
    state = { "done" => { "done" => { "type" => "plain_text_input", "value" => done } }, "hours" => { "hours" => { "type" => "static_select", "selected_option" => hours && { "value" => hours } } } }
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => "U0MEMBER" }, "channel" => { "id" => "U0MEMBER" }, "trigger_id" => "t", "response_url" => "https://hooks.slack.test/r",
                                    "state" => { "values" => state }, "actions" => [ { "action_id" => "huddle_done:#{choice}", "value" => @session.public_id } ] })
  end

  def pick(choice)
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => "U0MEMBER" }, "trigger_id" => "t", "response_url" => "https://hooks.slack.test/r",
                                    "actions" => [ { "action_id" => "huddle_goal:pick", "block_id" => @session.public_id, "type" => "radio_buttons", "selected_option" => { "value" => choice } } ] })
  end
end
