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
    refute policy(@reviewer).cut?, "only admins take an internal cut"
    assert policy(users(:admin)).cut?

    @submission.update!(flagged_at: Time.current, flag_reason: "x")
    refute policy(@reviewer).decide?
    refute policy(@reviewer).unflag?
    assert policy(users(:admin)).unflag?

    @submission.update!(flagged_at: nil, status: "approved")
    refute policy(@reviewer).decide?
  end

  test "only an admin off the team signs off a held decision, and only they claim it" do
    assert SubmissionReview.new(@submission, reviewer: @reviewer, verdict: "returned", feedback: "More photos", internal_reason: "Thin",
      rubric: Submission::RUBRIC.keys.index_with { "yes" }).save
    @submission.reload
    users(:admin).update!(roles: %w[user admin])
    refute policy(@reviewer).claim?, "the reviewer waits for an admin"
    refute policy(@reviewer).sign_off?
    assert policy(users(:admin)).sign_off?
    assert policy(users(:admin)).claim?
    refute policy(users(:admin)).decide?, "signing off isn't a fresh review"
    users(:member).update!(roles: %w[user admin])
    refute policy(users(:member)).sign_off?, "not their own team's"
    @reviewer.update!(roles: %w[user admin])
    refute policy(@reviewer).sign_off?, "not their own decision, once they're an admin"
  end
end
