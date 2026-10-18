require "test_helper"

class TimersTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "starts, shows and stops the timer" do
    sign_in_as users(:member)

    post timer_path
    assert_response :success
    assert_equal "timer", response.parsed_body["running"]
    assert_equal 1, users(:member).timer_sessions.running.count

    get timer_path
    assert_equal "timer", response.parsed_body["running"]

    delete timer_path
    assert_nil response.parsed_body["running"]
    assert_equal 0, users(:member).timer_sessions.running.count

    stop = users(:member).timer_sessions.last.versions.last
    assert_equal [ "update", users(:member).id.to_s, "web:timers#destroy" ], [ stop.event, stop.whodunnit, stop.source ]
    assert_nil stop.object_changes["stopped_at"].first
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
