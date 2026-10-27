require "test_helper"

class JoinTeamChannelJobTest < ActiveJob::TestCase
  test "picking or switching a pet adds them to its channel" do
    with_fake_slack do |slack|
      with_env("SLACK_LULU_CHANNEL_ID" => "CLULU", "SLACK_SAMI_CHANNEL_ID" => "CSAMI") do
        users(:newcomer).update!(slack_id: "U0NEWBIE")
        assert_no_enqueued_jobs(only: JoinTeamChannelJob) { users(:newcomer).update!(display_name: "Newbie") }
        assert_enqueued_with(job: JoinTeamChannelJob) { users(:newcomer).update!(pet: "sami") }
        assert_enqueued_with(job: JoinTeamChannelJob) { users(:newcomer).update!(pet: "lulu") }
        perform_enqueued_jobs(only: JoinTeamChannelJob)
      end

      assert_equal [ { channel: "CLULU", users: "U0NEWBIE" } ] * 2, slack.calls_to(:conversations_invite)
    end
  end

  test "does nothing without a channel for their pet" do
    with_fake_slack do |slack|
      with_env("SLACK_SAMI_CHANNEL_ID" => nil) do
        JoinTeamChannelJob.perform_now(users(:newcomer).tap { it.assign_attributes(slack_id: "U0NEWBIE", pet: "sami") })
      end
      assert_empty slack.calls_to(:conversations_invite)
    end
  end
end
