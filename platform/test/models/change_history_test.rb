require "test_helper"

class ChangeHistoryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class RenameJob < ApplicationJob
    def perform(user) = user.update!(display_name: "Renamed by a job")
  end

  class RenameTestAction < SlackBot::Action
    def call = user.update!(display_name: "Renamed from Slack")
  end

  test "a job's changes name the job and whoever enqueued it" do
    admin = users(:admin)
    PaperTrail.request(whodunnit: admin.id.to_s) { RenameJob.perform_later(users(:member)) }
    perform_enqueued_jobs

    version = users(:member).versions.last
    assert_equal admin.id.to_s, version.whodunnit
    assert_equal "job:ChangeHistoryTest::RenameJob", version.source
    assert_equal "Renamed by a job", version.object_changes["display_name"].last
  end

  test "a scheduled job's changes have no person" do
    RenameJob.perform_now(users(:member))

    assert_nil users(:member).versions.last.whodunnit
  end

  test "changes from Slack name the person who sent it and the handler" do
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => users(:member).slack_id }, "actions" => [ { "action_id" => "change_history_test/rename_test" } ] })

    version = users(:member).versions.last
    assert_equal users(:member).id.to_s, version.whodunnit
    assert_equal "slack:ChangeHistoryTest::RenameTestAction", version.source
  end
end
