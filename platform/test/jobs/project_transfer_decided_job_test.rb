require "test_helper"

class ProjectTransferDecidedJobTest < ActiveJob::TestCase
  test "an approval DMs the XP, the new project and the reviewer's message" do
    transfer = project_transfers(:stardance)
    with_fake_slack do |slack|
      perform_enqueued_jobs(only: ProjectTransferDecidedJob) do
        assert transfer.approve(reviewer: users(:admin), minutes: 90, xp: 12, message: "Welcome aboard <3 & enjoy")
      end
      message = slack.calls_to(:chat_postMessage).sole
      assert_equal users(:member).slack_id, message[:channel]
      assert message[:text].start_with?("Your project transfer for *Hexapod robot* was approved, with +12 XP!"), message[:text]
      assert_includes message[:text], "It's now a new project on Fallen, *Hexapod robot*."
      assert_not_includes message[:text], "counted"
      assert_includes message[:text], "> Welcome aboard &lt;3 &amp; enjoy"
      assert_includes message[:blocks].to_s, transfer.project.public_id
    end
  end

  test "an approval into an existing project says so, and leaves out zero XP" do
    transfer = project_transfers(:stardance)
    with_fake_slack do |slack|
      perform_enqueued_jobs(only: ProjectTransferDecidedJob) do
        assert transfer.approve(reviewer: users(:admin), minutes: 60, xp: 0, project: projects(:station))
      end
      text = slack.calls_to(:chat_postMessage).sole[:text]
      assert_includes text, "Its journals were added to *#{projects(:station).title}*."
      assert_includes text, "was approved!"
      assert_not_includes text, "note from the reviewer"
    end
  end

  test "an approval into a team project tells the rest of the team, without the XP or the reviewer's message" do
    transfer = project_transfers(:stardance)
    projects(:admins).memberships.create!(user: users(:member))
    with_fake_slack do |slack|
      perform_enqueued_jobs(only: ProjectTransferDecidedJob) do
        assert transfer.approve(reviewer: users(:admin), minutes: 60, xp: 8, project: projects(:admins), message: "Nice work")
      end
      messages = slack.calls_to(:chat_postMessage).index_by { it[:channel] }
      assert_equal [ users(:admin).slack_id, users(:member).slack_id ].sort, messages.keys.sort
      assert messages[users(:member).slack_id][:text].start_with?("Your project transfer for *Hexapod robot* was approved, with +8 XP!")

      team = messages[users(:admin).slack_id][:text]
      assert_equal "Member Person's project transfer for *Hexapod robot* was approved, and its journals were added to *Admin's thing*.", team
      assert_includes messages[users(:admin).slack_id][:blocks].to_s, projects(:admins).public_id
    end
  end

  test "a banned teammate isn't told" do
    transfer = project_transfers(:stardance)
    projects(:admins).memberships.create!(user: users(:member))
    users(:admin).update_column(:is_banned, true)
    with_fake_slack do |slack|
      perform_enqueued_jobs(only: ProjectTransferDecidedJob) do
        assert transfer.approve(reviewer: users(:admin), minutes: 60, xp: 0, project: projects(:admins))
      end
      assert_equal [ users(:member).slack_id ], slack.calls_to(:chat_postMessage).pluck(:channel)
    end
  end

  test "a rejection DMs the decision and the message" do
    transfer = project_transfers(:stardance)
    with_fake_slack do |slack|
      perform_enqueued_jobs(only: ProjectTransferDecidedJob) do
        assert transfer.reject(reviewer: users(:admin), note: "Duplicate", message: "This one was already transferred.")
      end
      message = slack.calls_to(:chat_postMessage).sole
      assert_includes message[:text], "Your project transfer for *Hexapod robot* wasn't approved."
      assert_includes message[:text], "> This one was already transferred."
      assert_not_includes message[:text], "Duplicate", "the staff note stays with staff"
      assert_not_includes message[:blocks].to_s, "See the project"
    end
  end

  test "nothing for someone without Slack linked" do
    transfer = project_transfers(:stardance)
    users(:member).update_column(:slack_id, nil)
    with_fake_slack do |slack|
      perform_enqueued_jobs(only: ProjectTransferDecidedJob) { transfer.reject(reviewer: users(:admin)) }
      assert_empty slack.calls_to(:chat_postMessage)
    end
  end
end
