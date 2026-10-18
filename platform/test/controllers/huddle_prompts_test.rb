require "test_helper"

class HuddlePromptsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = users(:member)
    @huddle = Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", started_at: 1.hour.ago)
    sign_in_as @user
  end

  test "Start while chilling in the huddle counts again and asks in a fresh DM" do
    session = @huddle.sessions.create!(slack_id: @user.slack_id, user: @user, joined_at: 10.minutes.ago, mode: "chilling", prompt_dm_ts: "1.1", dm_channel_id: "D1")

    with_env("SLACK_HUDDLE_CHANNEL_ID" => "CHUDDLE") do
      assert_enqueued_with(job: HuddlePromptJob, args: [ session, { dm: true } ]) { post huddle_prompt_path }
    end
    assert_equal [ nil, nil ], session.reload.slice(:mode, :prompt_dm_ts).values
    assert_equal "huddle", response.parsed_body["running"]
  end

  test "outside the huddle nothing is asked" do
    with_env("SLACK_HUDDLE_CHANNEL_ID" => "CHUDDLE") do
      assert_no_enqueued_jobs(only: HuddlePromptJob) { post huddle_prompt_path }
    end
    assert_response :success
  end
end
