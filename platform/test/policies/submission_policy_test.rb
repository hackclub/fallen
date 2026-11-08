require "test_helper"

class SubmissionPolicyTest < ActiveSupport::TestCase
  test "the team submits and takes back; nobody else" do
    submission = submit_design(projects(:station))

    assert SubmissionPolicy.new(users(:member), Submission.new(project: projects(:station))).create?
    refute SubmissionPolicy.new(users(:newcomer), Submission.new(project: projects(:station))).create?
    assert SubmissionPolicy.new(users(:member), submission).destroy?
    refute SubmissionPolicy.new(users(:newcomer), submission).destroy?

    submission.update!(status: "approved")
    refute SubmissionPolicy.new(users(:member), submission).destroy?
  end
end
