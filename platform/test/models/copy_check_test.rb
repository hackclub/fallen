require "test_helper"

class CopyCheckTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  MATCH = { "status" => "match", "reason" => nil, "mode" => "pcb", "matches" => [ { "repo" => "someone/board", "url" => "https://github.com/someone/board", "containment" => 0.97, "mode" => "pcb", "blocks" => [] } ] }.freeze
  CLEAR = { "status" => "clear", "reason" => nil, "mode" => "pcb", "matches" => [] }.freeze

  setup do
    @submission = submit_design(projects(:station))
    @admin = users(:admin)
  end

  test "without a checker nothing is checked or queued" do
    refute CopyCheck.available? if !Object.const_defined?(:CopyChecker) || !CopyChecker.configured?
    assert_no_enqueued_jobs { CopyCheck.later(@submission) } unless CopyCheck.available?
  end

  test "a result is saved on the submission, and a match holds approval until it is compared" do
    with_copy_checker(fake_copy_checker(MATCH)) do
      CopyCheck.run(@submission)
    end
    assert_equal "match", @submission.reload.copy_check["status"]
    assert_equal 1, @submission.copy_check["attempts"]
    assert @submission.copy_check_holds_approval?

    CopyCheck.compared!(@submission, @admin, copied: false, note: "Both started from the hackpad template")
    refute @submission.reload.copy_check_holds_approval?
    assert_equal @admin, @submission.copy_check_cleared_by
    assert_equal false, @submission.copy_check.dig("compared", "copied")
    assert_match "not a copy. Both started from the hackpad template", @submission.project.reviewer_notes.last.body
  end

  test "marking a match as copied keeps approval locked and says so in the notes" do
    with_copy_checker(fake_copy_checker(MATCH)) { CopyCheck.run(@submission) }
    CopyCheck.compared!(@submission.reload, @admin, copied: true)
    assert @submission.reload.copy_check_holds_approval?
    assert_match "it is copied", @submission.project.reviewer_notes.last.body
  end

  test "only a match can be compared" do
    with_copy_checker(fake_copy_checker(CLEAR)) { CopyCheck.run(@submission) }
    assert_raises(ArgumentError) { CopyCheck.compared!(@submission.reload, @admin, copied: false) }
  end

  test "another Fallen project sending the same repository is a match" do
    other = submit_design(projects(:unlinked))
    other.update_columns(repo_url: "https://github.com/someone/thing")
    @submission.update_columns(repo_url: "https://github.com/Someone/thing.git")
    with_copy_checker(fake_copy_checker(CLEAR)) { CopyCheck.run(@submission) }

    check = @submission.reload.copy_check
    assert_equal "match", check["status"]
    assert_equal "same_repo", check["reason"]
    assert_equal [ projects(:unlinked).public_id ], check["same_repo"].pluck("project")
  end

  test "a check that couldn't finish stays pending, and a finished one isn't run again" do
    checker = fake_copy_checker({ "status" => "pending", "error" => "rate limited" }, CLEAR)
    with_copy_checker(checker) do
      CopyCheck.run(@submission)
      assert_equal "pending", @submission.reload.copy_check["status"]
      CopyCheck.run(@submission)
      assert_equal "clear", @submission.reload.copy_check["status"]
      assert_equal 2, @submission.copy_check["attempts"]
      CopyCheck.run(@submission)
      assert_equal 2, checker.asked.size
    end
  end

  test "checking again clears the result and who compared it" do
    with_copy_checker(fake_copy_checker(MATCH)) do
      CopyCheck.run(@submission)
      CopyCheck.compared!(@submission.reload, @admin, copied: false)
      assert_enqueued_with(job: CopyCheckJob) { CopyCheck.rescreen(@submission) }
    end
    assert_equal({ "status" => "pending", "attempts" => 0 }, @submission.reload.copy_check)
    assert_nil @submission.copy_check_cleared_at
  end

  test "the sweep queues decisions waiting on sign-off that haven't been checked" do
    reviewer = users(:newcomer)
    reviewer.update!(roles: %w[user design_reviewer])
    journals = SubmissionReview.journals_for(@submission).to_h { [ it.public_id, { "approved_minutes" => it.duration_minutes } ] }
    with_copy_checker(fake_copy_checker) do
      assert_enqueued_with(job: CopyCheckJob, args: [ @submission ]) do
        review = SubmissionReview.new(@submission, reviewer:, verdict: "approved", internal_reason: "Fine",
          rubric: Submission::RUBRIC.keys.index_with { "yes" }, journals:)
        assert review.save, review.errors.full_messages.to_sentence
        assert review.proposed?
      end
      clear_enqueued_jobs
      assert_enqueued_jobs(1, only: CopyCheckJob) { CopyCheckSweepJob.perform_now }
    end
  end
end
