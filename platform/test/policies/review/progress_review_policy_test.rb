require "test_helper"

class Review::ProgressReviewPolicyTest < ActiveSupport::TestCase
  setup do
    @reviewer = users(:newcomer)
    @reviewer.update!(roles: %w[user reviewer])
    @review = ProgressReview.new(project: projects(:station), reviewer: @reviewer, verdict: "approved", feedback: "Nice")
  end

  def policy(user, record = @review) = Review::ProgressReviewPolicy.new(user, record)

  test "the reviewer who wrote it and admins edit it; other reviewers and the team don't" do
    assert policy(@reviewer).update?
    assert policy(users(:admin)).update?
    users(:member).update!(roles: %w[user reviewer])
    refute policy(users(:member)).update?, "another reviewer's"
    users(:member).update!(roles: %w[user])
    refute policy(users(:member)).update?
    refute policy(nil).update?
  end

  test "a dismissal, which nobody was sent, has nothing to edit" do
    @review.verdict = "dismissed"
    refute policy(@reviewer).update?
  end

  test "a reviewer who lost the role can't edit what they wrote" do
    @reviewer.update!(roles: %w[user])
    refute policy(@reviewer).update?
  end
end
