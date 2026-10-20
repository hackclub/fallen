require "test_helper"

class TimeMilestoneJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = users(:member)
    @user.journals.kept.update_all(created_at: 5.hours.ago)
    @huddle = Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", thread_ts: "1700000000.000100", started_at: 1.day.ago)
  end

  test "checks in once an hour in their DMs, saying it is the huddle counting" do
    session = @huddle.sessions.create!(slack_id: @user.slack_id, user: @user, joined_at: 65.minutes.ago, mode: "working")

    with_fake_slack do |slack|
      run_job
      run_job
      message = slack.calls_to(:chat_postMessage).sole
      assert_equal @user.slack_id, message[:channel]
      assert_match "tracking your time in the huddle, *1 hour* so far. What have you gotten done?", message[:blocks].first[:text][:text]
      assert_equal %w[time_check_in:save time_check_in:stop], message[:blocks].last[:elements].pluck(:action_id)
      assert_equal "Stop counting", message[:blocks].last[:elements].last[:text][:text]
      assert_equal [ @user.slack_id, "1700009999.000001" ], @user.time_milestones.sole.values_at(:dm_channel_id, :dm_ts)

      session.update!(joined_at: 95.minutes.ago)
      run_job
      assert_equal 1, slack.calls_to(:chat_postMessage).size, "no check-in at the half hour"
      assert_empty slack.calls_to(:chat_postEphemeral)
    end
  end

  test "someone on the site's timer hears it is the timer, and a long stretch found late gets one message" do
    @user.timer_sessions.create!(started_at: 2.hours.ago - 1.minute)

    with_fake_slack do |slack|
      run_job
      message = slack.calls_to(:chat_postMessage).sole
      assert_match "Your Fallen timer is running, 2 hours so far", message[:text]
      assert_equal "Stop the timer", message[:blocks].last[:elements].last[:text][:text]
    end
  end

  test "nothing while paused, chilling, or under an hour" do
    @huddle.sessions.create!(slack_id: @user.slack_id, user: @user, joined_at: 70.minutes.ago, mode: "working")
    @user.huddle_pauses.create!(started_at: 1.minute.ago)
    @huddle.sessions.create!(slack_id: "U0ADMIN", user: users(:admin), joined_at: 70.minutes.ago, mode: "chilling")
    users(:newcomer).timer_sessions.create!(started_at: 50.minutes.ago)

    with_fake_slack do |slack|
      run_job
      assert_empty slack.calls
    end
  end

  test "a new journal starts the check-ins again" do
    @user.timer_sessions.create!(started_at: 70.minutes.ago)
    with_fake_slack do |slack|
      run_job
      @user.journals.kept.first.update_columns(created_at: 65.minutes.ago)
      run_job
      assert_equal 2, slack.calls_to(:chat_postMessage).size
    end
  end

  test "Save keeps the answer, and the pet stops asking" do
    @user.timer_sessions.create!(started_at: 70.minutes.ago)
    with_fake_slack do |slack|
      run_job
      check_in = @user.time_milestones.sole
      assert_equal check_in, TrackedTime.new(@user).check_in

      press("save", check_in, done: " ")
      assert_match "Write what you've gotten done first", slack.calls_to(:response_url).last[:body]["blocks"].to_s
      assert_nil check_in.reload.done

      press("save", check_in, done: "Wired the matrix")
      assert_equal "Wired the matrix", check_in.reload.done
      reply = slack.calls_to(:response_url).last[:body]
      assert_match "*1 hour* in, you got done: Wired the matrix", reply["blocks"].first["text"]["text"]
      assert_equal %w[time_check_in:stop], reply["blocks"].last["elements"].pluck("action_id"), "still counting, so it can still stop"
      assert_nil TrackedTime.new(@user).check_in
    end
  end

  test "Stop stops the site timer, keeping what was typed" do
    @user.timer_sessions.create!(started_at: 70.minutes.ago)
    with_fake_slack do |slack|
      run_job
      check_in = @user.time_milestones.sole

      press("stop", check_in, done: "Half the matrix")
      assert_equal 0, @user.timer_sessions.running.count
      assert_equal "Half the matrix", check_in.reload.done
      reply = slack.calls_to(:response_url).last[:body]
      assert_match "Stopped", reply["blocks"].to_s
      assert_not reply["blocks"].any? { |block| block["type"] == "actions" }
    end
  end

  test "Stop in the huddle pauses without taking them out" do
    @huddle.sessions.create!(slack_id: @user.slack_id, user: @user, joined_at: 65.minutes.ago, mode: "working")
    with_fake_slack do |slack|
      run_job
      press("stop", @user.time_milestones.sole)
      assert_equal "paused", TrackedTime.new(@user).running
      assert_match "Paused", slack.calls_to(:response_url).last[:body]["blocks"].to_s
    end
  end

  test "someone else's check-in is left alone" do
    @user.timer_sessions.create!(started_at: 70.minutes.ago)
    with_fake_slack do |slack|
      run_job
      press("stop", @user.time_milestones.sole, user: "U0ADMIN")
      assert_equal 1, @user.timer_sessions.running.count
      assert_empty slack.calls_to(:response_url)
    end
  end

  private

  def run_job = with_env("SLACK_HUDDLE_CHANNEL_ID" => "CHUDDLE") { TimeMilestoneJob.perform_now }

  def press(choice, check_in, done: nil, user: "U0MEMBER")
    state = { SlackMessages::TIME_CHECK_IN_INPUT => { SlackMessages::TIME_CHECK_IN_INPUT => { "type" => "plain_text_input", "value" => done } } }
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => user }, "channel" => { "id" => user }, "trigger_id" => "t", "response_url" => "https://hooks.slack.test/r",
                                    "state" => { "values" => state }, "actions" => [ { "action_id" => "time_check_in:#{choice}", "value" => check_in.public_id } ] })
  end
end
