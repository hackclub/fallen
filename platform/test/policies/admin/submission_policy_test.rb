require "test_helper"

class Admin::SubmissionPolicyTest < ActiveSupport::TestCase
  test "only admins off the team sign off or send back a held decision, and only while it's held" do
    submission = submit_design(projects(:station))
    designer = users(:newcomer).tap { it.update!(roles: %w[user design_reviewer]) }
    SubmissionReview.new(submission, reviewer: designer, verdict: "returned", feedback: "More photos", internal_reason: "Thin",
      rubric: Submission::RUBRIC.keys.index_with { "yes" }).save or flunk("not held")
    admin = users(:admin)
    teammate = users(:member).tap { it.update!(roles: %w[user admin]) }

    assert Admin::SubmissionPolicy.new(admin, submission).update?
    assert Admin::SubmissionPolicy.new(admin, submission).destroy?
    assert_not Admin::SubmissionPolicy.new(teammate, submission).update?, "their own team's project"
    assert_not Admin::SubmissionPolicy.new(teammate, submission).destroy?
    assert_not Admin::SubmissionPolicy.new(designer, submission).update?
    assert_not Admin::SubmissionPolicy.new(designer, Submission).index?
    assert Admin::SubmissionPolicy.new(admin, Submission).index?

    assert_includes Admin::SubmissionPolicy::Scope.new(admin, Submission).resolve, submission
    assert_not_includes Admin::SubmissionPolicy::Scope.new(teammate, Submission).resolve, submission
    assert_empty Admin::SubmissionPolicy::Scope.new(designer, Submission).resolve

    SubmissionReview.send_back(submission, admin)
    assert_not Admin::SubmissionPolicy.new(admin, submission.reload).update?, "nothing held"
  end
end
