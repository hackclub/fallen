require "test_helper"

class JoinMembersChannelJobTest < ActiveJob::TestCase
  test "finishing sign-in adds them to the members channel" do
    with_fake_slack do |slack|
      with_env("SLACK_MEMBERS_CHANNEL_ID" => "CMEMBERS") do
        users(:newcomer).update!(slack_id: "U0NEWBIE")
        assert_no_enqueued_jobs(only: JoinMembersChannelJob) { users(:newcomer).update!(display_name: "Newbie") }
        assert_enqueued_with(job: JoinMembersChannelJob) { users(:newcomer).update!(pet: "sami") }
        perform_enqueued_jobs(only: JoinMembersChannelJob)
      end

      assert_equal [ { channel: "CMEMBERS", users: "U0NEWBIE" } ], slack.calls_to(:conversations_invite)
    end
  end

  test "does nothing without a members channel" do
    with_fake_slack do |slack|
      with_env("SLACK_MEMBERS_CHANNEL_ID" => nil) { JoinMembersChannelJob.perform_now(users(:newcomer).tap { it.slack_id = "U0NEWBIE" }) }
      assert_empty slack.calls_to(:conversations_invite)
    end
  end
end
