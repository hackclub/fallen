require "test_helper"

class TimersTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  test "starts, shows and stops the timer" do
    sign_in_as users(:member)

    post timer_path, params: { goal: "  Wire the   matrix " }
    assert_response :success
    assert_equal [ "timer", 6 ], response.parsed_body.values_at("running", "max_hours")
    assert_equal "Wire the matrix", users(:member).timer_sessions.running.sole.goal

    get timer_path
    assert_equal "timer", response.parsed_body["running"]

    delete timer_path
    assert_nil response.parsed_body["running"]
    assert_equal 0, users(:member).timer_sessions.running.count

    stop = users(:member).timer_sessions.last.versions.last
    assert_equal [ "update", users(:member).id.to_s, "web:timers#destroy" ], [ stop.event, stop.whodunnit, stop.source ]
    assert_nil stop.object_changes["stopped_at"].first
  end

  test "starting needs a goal" do
    sign_in_as users(:member)

    post timer_path, params: { goal: " " }
    assert_response :unprocessable_content
    assert_equal 0, users(:member).timer_sessions.count
  end

  test "a stopped timer asks what they got done, and fewer honest hours come off the time" do
    user = users(:member)
    user.journals.update_all(discarded_at: Time.current)
    sign_in_as user
    freeze_time do
      user.timer_sessions.create!(started_at: 2.hours.ago, goal: "Case")
      delete timer_path
      assert_equal({ "goal" => "Case", "hours" => "2" }, response.parsed_body["wrap_up"])

      post timer_wrap_up_path, params: { done: "Wired it", hours: "2.5" }
      assert_response :unprocessable_content
      assert_equal "Hours can be at most 2", response.parsed_body["error"]

      post timer_wrap_up_path, params: { done: "Wired it", hours: "1.5" }
      assert_equal [ nil, 90.minutes.to_i ], response.parsed_body.values_at("wrap_up", "seconds")
      assert_equal [ "Wired it", 30.minutes.to_i ], user.timer_sessions.sole.slice(:done, :deducted_seconds).values
    end
  end

  test "a timer that ran out asks too, and all of it can be kept" do
    user = users(:member)
    user.journals.update_all(discarded_at: Time.current)
    sign_in_as user
    freeze_time do
      timer = user.timer_sessions.create!(started_at: 7.hours.ago)
      get timer_path
      assert_equal "6", response.parsed_body.dig("wrap_up", "hours")

      post timer_wrap_up_path, params: { done: " ", hours: "6" }
      assert_equal "Say what you got done first", response.parsed_body["error"]

      post timer_wrap_up_path, params: { done: "Wired it", hours: "6" }
      assert_equal [ nil, 6.hours.to_i ], response.parsed_body.values_at("wrap_up", "seconds")
      assert_equal [ timer.started_at + 6.hours, 0 ], timer.reload.slice(:stopped_at, :deducted_seconds).values
    end
  end

  test "a misclick is not asked about" do
    sign_in_as users(:member)
    freeze_time do
      users(:member).timer_sessions.create!(started_at: 10.seconds.ago, stopped_at: Time.current)
      get timer_path
      assert_nil response.parsed_body["wrap_up"]
    end
  end

  test "gives the live huddle's link" do
    Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", started_at: 1.hour.ago, link: "https://app.slack.com/huddle/T1/CHUDDLE")
    sign_in_as users(:member)

    with_env("SLACK_HUDDLE_CHANNEL_ID" => "CHUDDLE") { get timer_path }
    assert_equal "https://hackclub.slack.com/huddle/CHUDDLE", response.parsed_body["huddle_url"]
  end

  test "can ring and link the huddle without the huddle account's session on the web" do
    sign_in_as users(:member)

    with_env("SLACK_HUDDLE_CHANNEL_ID" => "CHUDDLE", "SLACK_BROWSER_TOKEN" => nil) { get timer_path }
    assert_equal [ true, "https://hackclub.slack.com/huddle/CHUDDLE" ], response.parsed_body.values_at("can_ring", "huddle_url")
  end

  test "Invite me rings them into the huddle" do
    sign_in_as users(:member)
    assert_enqueued_with(job: HuddleRingJob, args: [ users(:member) ]) { post huddle_invite_path }
    assert_response :accepted
  end

  test "an admin browsing as someone cannot start their timer" do
    sign_in_as users(:admin)
    post impersonate_admin_user_path(users(:member))

    post timer_path
    assert_equal 0, users(:member).timer_sessions.count
  end

  test "needs a session" do
    post timer_path
    assert_response :redirect
    assert_equal 0, TimerSession.count
  end
end
