require "test_helper"

class Review::ProgressStatusPolicyTest < ActiveSupport::TestCase
  setup do
    projects(:station).journals.kept.update_all(duration_minutes: ProgressStatus::FIRST_AT_MINUTES)
    @status = ProgressStatus.refresh(projects(:station))
    @reviewer = users(:newcomer)
    @reviewer.update!(roles: %w[user reviewer])
  end

  def policy(user, record = @status) = Review::ProgressStatusPolicy.new(user, record)

  test "reviewers and admins review; design reviewers and everyone else see nothing" do
    assert policy(@reviewer).decide?
    assert policy(users(:admin)).decide?
    users(:banned).update_columns(roles: %w[user design_reviewer])
    refute policy(users(:banned)).show?
    assert_empty Review::ProgressStatusPolicy::Scope.new(users(:banned), ProgressStatus).resolve
    assert_equal [ @status ], Review::ProgressStatusPolicy::Scope.new(@reviewer, ProgressStatus).resolve.to_a
  end

  test "not their own team's, not once flagged or not due, and only admins clear an AI flag" do
    users(:member).update!(roles: %w[user reviewer])
    refute policy(users(:member)).decide?
    refute policy(users(:member)).star?, "no starring your own project"

    @status.update!(flagged_at: Time.current, flag_reason: "x")
    refute policy(@reviewer).decide?
    refute policy(@reviewer).flag?
    refute policy(@reviewer).unflag?
    assert policy(users(:admin)).unflag?
    assert policy(@reviewer).star?

    @status.update!(flagged_at: nil, due_since: nil, due_reason: nil)
    refute policy(@reviewer).decide?
  end
end
