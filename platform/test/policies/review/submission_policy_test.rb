require "test_helper"

class Review::SubmissionPolicyTest < ActiveSupport::TestCase
  setup do
    @submission = submit_design(projects(:station))
    @reviewer = users(:newcomer)
    @reviewer.update!(roles: %w[user design_reviewer])
  end

  def policy(user, record = @submission) = Review::SubmissionPolicy.new(user, record)

  test "design reviewers and admins review; everyone else sees nothing" do
    assert policy(@reviewer).decide?
    assert policy(users(:admin)).decide?
    refute policy(users(:banned)).show?
    assert_empty Review::SubmissionPolicy::Scope.new(users(:banned), Submission).resolve
    assert_equal [ @submission ], Review::SubmissionPolicy::Scope.new(@reviewer, Submission).resolve.to_a
  end

  test "not their own team's, not once decided or flagged, and only admins reject or clear a flag" do
    users(:member).update!(roles: %w[user design_reviewer])
    refute policy(users(:member)).decide?
    refute policy(@reviewer).reject?
    assert policy(users(:admin)).reject?

    @submission.update!(flagged_at: Time.current, flag_reason: "x")
    refute policy(@reviewer).decide?
    refute policy(@reviewer).unflag?
    assert policy(users(:admin)).unflag?

    @submission.update!(flagged_at: nil, status: "approved")
    refute policy(@reviewer).decide?
  end
end
