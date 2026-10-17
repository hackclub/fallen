require "test_helper"

# == Schema Information
#
# Table name: projects
#
#  id               :bigint           not null, primary key
#  demo_url         :string
#  description      :text
#  discarded_at     :datetime
#  repo_url         :string
#  slack_thread_ts  :string
#  title            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  slack_channel_id :string
#  user_id          :bigint           not null
#
# Indexes
#
#  index_projects_on_discarded_at                          (discarded_at)
#  index_projects_on_slack_channel_id_and_slack_thread_ts  (slack_channel_id,slack_thread_ts) UNIQUE WHERE (slack_thread_ts IS NOT NULL)
#  index_projects_on_updated_at                            (updated_at)
#  index_projects_on_user_id                               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ProjectTest < ActiveSupport::TestCase
  test "finds a kept project by its slack thread" do
    assert_equal projects(:station), Project.find_by_slack_thread("CJOURNALS", "1700000000.000100")
    assert_nil Project.find_by_slack_thread("CJOURNALS", "nope")
    projects(:station).discard
    assert_nil Project.find_by_slack_thread("CJOURNALS", "1700000000.000100")
  end

  test "totals only kept journals" do
    assert_equal 90, projects(:station).total_minutes
    assert_equal 2, projects(:station).journal_count
    journals(:first).discard
    assert_equal 0, projects(:station).total_minutes
  end

  test "discarding a project discards its journals" do
    projects(:station).discard
    assert journals(:first).reload.discarded?
    assert journals(:pending_hours).reload.discarded?
  end

  test "destroy only discards, for the project, its journals and its owner" do
    assert_no_difference -> { Project.count + Journal.count + User.count + ActiveStorage::Attachment.count } do
      projects(:station).destroy
      users(:member).destroy!
      Project.where(id: projects(:station).id).destroy_all
    end
    assert projects(:station).reload.discarded?
    assert journals(:first).reload.discarded?
    assert users(:member).reload.discarded?
  end

  test "links must be urls" do
    project = users(:member).projects.build(title: "x", repo_url: "github.com/x")
    assert_not project.valid?
    project.repo_url = "https://github.com/x"
    assert project.valid?
  end
end
