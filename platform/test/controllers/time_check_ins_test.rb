require "test_helper"

class TimeCheckInsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = users(:member)
    @user.journals.kept.update_all(created_at: 3.hours.ago)
    @user.timer_sessions.create!(started_at: 70.minutes.ago)
    @check_in = @user.time_milestones.create!(since: @user.journals.kept.maximum(:created_at), minutes: 60, dm_channel_id: "D1", dm_ts: "1.2")
    sign_in_as @user
  end

  test "the pet asks, and an answer there shows in the DM too" do
    get timer_path
    assert_equal({ "id" => @check_in.public_id, "so_far" => "1 hour" }, response.parsed_body["check_in"])

    patch time_check_in_path(@check_in), params: { done: " " }
    assert_response :unprocessable_content

    with_fake_slack do |slack|
      perform_enqueued_jobs(only: TimeCheckInDmJob) { patch time_check_in_path(@check_in), params: { done: "Wired the matrix" } }
      assert_nil response.parsed_body["check_in"]
      assert_equal "Wired the matrix", @check_in.reload.done
      update = slack.calls_to(:chat_update).sole
      assert_equal [ "D1", "1.2" ], update.values_at(:channel, :ts)
      assert_match "you got done: Wired the matrix", update[:text]
    end
  end

  test "an older check-in is not asked once a newer one exists, nor once nothing is counting" do
    @user.time_milestones.create!(since: @check_in.since, minutes: 120, done: "More", answered_at: Time.current)
    get timer_path
    assert_nil response.parsed_body["check_in"]

    @user.time_milestones.where(minutes: 120).delete_all
    TimerSession.stop(@user)
    get timer_path
    assert_nil response.parsed_body["check_in"]
  end

  test "only their own" do
    sign_in_as users(:admin)
    patch time_check_in_path(@check_in), params: { done: "Nope" }
    assert_response :not_found
    assert_nil @check_in.reload.done
  end
end
