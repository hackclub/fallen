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
      assert_equal %w[huddle_goal:commit huddle_goal:chill], prompt[:blocks].last[:elements].pluck(:action_id)
    end
  end

  test "someone without a pet hears from the bot" do
    session = @huddle.sessions.create!(slack_id: "U0STRANGER", joined_at: 1.minute.ago)
    with_fake_slack do |slack|
      HuddlePromptJob.perform_now(session)
      assert_nil slack.calls_to(:chat_postEphemeral).sole[:username]
    end
  end

  test "commit stores the goal on every session they have in the huddle" do
    earlier = @huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 50.minutes.ago, left_at: 40.minutes.ago)
    with_fake_slack do |slack|
      press("commit", goal: "  Soldering the  keyboard ")

      assert_equal [ [ "working", "Soldering the keyboard" ] ], [ @session.reload, earlier.reload ].map { |s| [ s.mode, s.goal ] }.uniq
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

  test "only the person asked can answer" do
    with_fake_slack do
      press("chill", user: "U0ADMIN")
      assert_nil @session.reload.mode
    end
  end

  test "the handoff mentions everyone with a link to the huddle" do
    with_fake_slack do |slack|
      HuddleHandoffJob.perform_now(@huddle, %w[U0MEMBER U0STRANGER])

      post = slack.calls_to(:chat_postMessage).sole
      assert_equal [ "CHUDDLE", "1700000000.000100" ], post.values_at(:channel, :thread_ts)
      assert_match "<@U0MEMBER> <@U0STRANGER>", post[:text]
      assert_equal "https://slack.com/archives/CHUDDLE/p1700000000000100", post[:blocks].last[:elements].sole[:url]
    end
  end

  private

  def post_in_thread(ts)
    SlackBot.handle(:event, { "type" => "event_callback", "event" => { "type" => "message", "channel" => "CHUDDLE", "user" => "U0MEMBER", "text" => "hi", "ts" => ts, "thread_ts" => @huddle.thread_ts } })
  end

  def press(choice, goal: nil, user: "U0MEMBER")
    state = { "goal" => { "goal" => { "type" => "plain_text_input", "value" => goal } } }
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => user }, "trigger_id" => "t", "response_url" => "https://hooks.slack.test/r",
                                    "state" => { "values" => state }, "actions" => [ { "action_id" => "huddle_goal:#{choice}", "value" => @session.public_id } ] })
  end
end
