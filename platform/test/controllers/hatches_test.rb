require "test_helper"

class HatchesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "the first hatch watched sends the pet's welcome once" do
    sign_in_as users(:member)
    assert_enqueued_with(job: HatchCelebrationJob, args: [ users(:member) ]) { post hatch_path }
    assert_redirected_to home_path
    assert users(:member).reload.hatch_seen_at?

    assert_no_enqueued_jobs(only: HatchCelebrationJob) { post hatch_path }
  end

  test "an egg that has not hatched sends nothing" do
    sign_in_as users(:newcomer)
    assert_no_enqueued_jobs(only: HatchCelebrationJob) { post hatch_path }
    assert_nil users(:newcomer).reload.hatch_seen_at
  end

  test "needs a session" do
    post hatch_path
    assert_response :redirect
    assert_nil users(:member).reload.hatch_seen_at
  end
end
