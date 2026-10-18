require "test_helper"

class TimeMilestoneJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = users(:member)
    @user.journals.kept.update_all(created_at: 3.hours.ago)
    @huddle = Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", thread_ts: "1700000000.000100", started_at: 1.day.ago)
  end

  test "congratulates once per half hour in the huddle's thread, only to them" do
    session = @huddle.sessions.create!(slack_id: @user.slack_id, user: @user, joined_at: 65.minutes.ago, mode: "working")

    with_fake_slack do |slack|
      run_job
      run_job
      message = slack.calls_to(:chat_postEphemeral).sole
      assert_equal [ "CHUDDLE", @user.slack_id, "1700000000.000100" ], message.values_at(:channel, :user, :thread_ts)
      assert message[:text].start_with?("1 hour since your last journal")

      session.update!(joined_at: 95.minutes.ago)
      run_job
      assert slack.calls_to(:chat_postEphemeral).last[:text].start_with?("1.5 hours")
      assert_equal 2, slack.calls_to(:chat_postEphemeral).size
    end
  end

  test "someone on the site's timer gets a DM, and a long stretch found late gets one message" do
    @user.timer_sessions.create!(started_at: 2.hours.ago - 1.minute)

    with_fake_slack do |slack|
      run_job
      message = slack.calls_to(:chat_postMessage).sole
      assert_equal @user.slack_id, message[:channel]
      assert message[:text].start_with?("2 hours since your last journal")
    end
  end

  test "nothing while paused, chilling, or under half an hour" do
    @huddle.sessions.create!(slack_id: @user.slack_id, user: @user, joined_at: 40.minutes.ago, mode: "working")
    @user.huddle_pauses.create!(started_at: 1.minute.ago)
    @huddle.sessions.create!(slack_id: "U0ADMIN", user: users(:admin), joined_at: 40.minutes.ago, mode: "chilling")
    users(:newcomer).timer_sessions.create!(started_at: 10.minutes.ago)

    with_fake_slack do |slack|
      run_job
      assert_empty slack.calls
    end
  end

  test "a new journal starts the milestones again" do
    @user.timer_sessions.create!(started_at: 40.minutes.ago)
    with_fake_slack do |slack|
      run_job
      @user.journals.kept.first.update_columns(created_at: 35.minutes.ago)
      run_job
      assert_equal 2, slack.calls_to(:chat_postMessage).size
    end
  end

  private

  def run_job = with_env("SLACK_HUDDLE_CHANNEL_ID" => "CHUDDLE") { TimeMilestoneJob.perform_now }
end
