require "test_helper"

class HuddlePausesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:member)
    @huddle = Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", started_at: 1.hour.ago)
    sign_in_as @user
  end

  test "pausing in the huddle stops counting, stops the site timer, and twice is the same as once" do
    @huddle.sessions.create!(slack_id: @user.slack_id, user: @user, joined_at: 10.minutes.ago, mode: "working")
    @user.timer_sessions.create!(started_at: 5.minutes.ago)

    post huddle_pause_path
    assert_equal "paused", response.parsed_body["running"]
    assert_equal 0, @user.timer_sessions.running.count
    pause = @user.huddle_pauses.sole

    post huddle_pause_path
    assert_equal [ pause ], @user.huddle_pauses.to_a

    delete huddle_pause_path
    assert_equal "huddle", response.parsed_body["running"]
    assert_equal "resumed", pause.reload.end_reason

    delete huddle_pause_path
    assert_equal pause.ended_at, pause.reload.ended_at
  end

  test "there is nothing to pause outside the huddle" do
    post huddle_pause_path
    assert_nil response.parsed_body["running"]
    assert_equal 0, @user.huddle_pauses.count
  end
end
