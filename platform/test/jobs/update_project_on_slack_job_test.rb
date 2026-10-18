require "test_helper"

class UpdateProjectOnSlackJobTest < ActiveJob::TestCase
  test "rewrites the anchor with the new title as the owner" do
    project = projects(:station)
    project.update!(title: "Robot arm")
    with_fake_slack do |slack|
      UpdateProjectOnSlackJob.perform_now(project)
      call = slack.calls_to(:chat_update).sole
      assert_equal [ project.slack_channel_id, project.slack_thread_ts ], [ call[:channel], call[:ts] ]
      assert call[:text].start_with?("Project name: Robot arm"), call[:text]
    end
  end

  test "leaves projects that are not on slack alone" do
    with_fake_slack do |slack|
      UpdateProjectOnSlackJob.perform_now(projects(:unlinked))
      assert_empty slack.calls
    end
  end
end
