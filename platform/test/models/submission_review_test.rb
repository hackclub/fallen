require "test_helper"

class SubmissionReviewTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @submission = submit_design(projects(:station))
    @reviewer = users(:admin)
    @reviewer.update!(roles: %w[user design_reviewer])
    @journals = SubmissionReview.journals_for(@submission).to_a
  end

  def calls(deflate: nil)
    @journals.to_h do |j|
      call = j == deflate ? { "approved_minutes" => j.duration_minutes / 3, "reason" => "Idle or AFK time" } : { "approved_minutes" => j.duration_minutes }
      [ j.public_id, call ]
    end
  end

  def review(verdict: "approved", feedback: "", journals: calls, bom: nil, reviewer: @reviewer)
    bom ||= @submission.bom_items.to_h { [ it.public_id, { "verdict" => "approved" } ] }
    SubmissionReview.new(@submission, reviewer:, verdict:, feedback:, internal_reason: "Looks right", rubric: Submission::RUBRIC.keys.index_with { "yes" }, journals:, bom:)
  end

  test "approving funds the approved lines and takes XP off a deflated journal" do
    journal = journals(:first)
    xp_before = journal.xp_entry.amount
    rp, shipping = @submission.bom_items
    bom = { rp.public_id => { "verdict" => "approved" }, shipping.public_id => { "verdict" => "adjusted", "approved_cents" => "300", "reason" => "Shipping or tax was off" } }

    assert review(journals: calls(deflate: journal), bom:).save
    @submission.reload

    assert @submission.approved?
    assert_equal 500, @submission.approved_cents
    assert_equal 500, @submission.grant_payout.amount_cents
    assert_equal 30, journal.reload.reviewed_minutes
    assert_operator journal.xp_entry.reload.amount, :<, xp_before
    assert_equal "Idle or AFK time", @submission.journal_reviews.find_by(journal:).reason
    assert_enqueued_jobs 1, only: SubmissionDecidedJob
  end

  test "every journal and every part needs a call, and a reason when it's cut" do
    partial = review(journals: calls.except(@journals.first.public_id))
    refute partial.save
    assert partial.errors[:journals].any?

    unreasoned = review(journals: calls.merge(@journals.first.public_id => { "approved_minutes" => 1 }))
    refute unreasoned.save
    assert_match "reason", unreasoned.errors[:journals].join

    too_much = review(journals: calls.merge(@journals.first.public_id => { "approved_minutes" => 10_000 }))
    refute too_much.save

    undecided_bom = review(bom: {})
    refute undecided_bom.save
    assert undecided_bom.errors[:bom].any?
    assert @submission.reload.pending?
  end

  test "returning needs feedback but not a decision on every part; rejecting needs an admin" do
    refute review(verdict: "returned").save
    assert review(verdict: "returned", feedback: "Add the gerbers", bom: {}).save
    assert @submission.reload.returned?
    assert_nil @submission.grant_payout

    other = submit_design(projects(:station))
    @submission = other
    refute review(verdict: "rejected", feedback: "Copied").save
    @reviewer.update!(roles: %w[user admin])
    assert review(verdict: "rejected", feedback: "Copied").save
  end

  test "nobody reviews their own team's project" do
    refute review(reviewer: projects(:station).user).save
  end

  test "one reviewer holds a submission at a time, and the queue skips what's held or theirs" do
    other = users(:newcomer)
    other.update!(roles: %w[user design_reviewer])

    assert SubmissionReview.claim(@submission, @reviewer)
    refute SubmissionReview.claim(@submission, other)
    assert_nil SubmissionReview.next_for(other)
    assert_equal @submission, SubmissionReview.next_for(@reviewer)
    refute review(reviewer: other).save

    @submission.update_columns(claim_expires_at: 1.minute.ago)
    assert SubmissionReview.claim(@submission, other)
    assert_nil SubmissionReview.next_for(projects(:station).user)
  end

  test "a later review starts from the time the last one counted" do
    journal = journals(:first)
    assert review(verdict: "returned", feedback: "More photos", journals: calls(deflate: journal), bom: {}).save

    assert_equal 30, journal.reload.reviewed_minutes
    assert_equal 30, journal.counted_minutes
  end
end
