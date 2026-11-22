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

  def review(verdict: "approved", feedback: "", journals: calls, reviewer: @reviewer, ai: nil, cut: nil)
    SubmissionReview.new(@submission, reviewer:, verdict:, feedback:, internal_reason: "Looks right", rubric: Submission::RUBRIC.keys.index_with { "yes" }, journals:, ai:, cut:)
  end

  test "approving funds the parts list as asked and takes XP off a deflated journal" do
    journal = journals(:first)
    xp_before = journal.xp_entry.amount
    asked = @submission.bom_items.sum(&:requested_cents)

    assert review(journals: calls(deflate: journal)).save
    @submission.reload

    assert @submission.approved?
    assert_operator asked, :>, 0
    assert_equal asked, @submission.approved_cents
    assert_equal asked, @submission.grant_payout.amount_cents
    assert @submission.bom_items.all? { it.verdict == "approved" }
    assert_equal 30, journal.reload.reviewed_minutes
    assert_operator journal.xp_entry.reload.amount, :<, xp_before
    assert_equal "Idle or AFK time", @submission.journal_reviews.find_by(journal:).reason
    assert_enqueued_jobs 1, only: SubmissionDecidedJob
  end

  test "every journal needs a call, and a reason when it's cut" do
    partial = review(journals: calls.except(@journals.first.public_id))
    refute partial.save
    assert partial.errors[:journals].any?

    unreasoned = review(journals: calls.merge(@journals.first.public_id => { "approved_minutes" => 1 }))
    refute unreasoned.save
    assert_match "reason", unreasoned.errors[:journals].join

    too_much = review(journals: calls.merge(@journals.first.public_id => { "approved_minutes" => 10_000 }))
    refute too_much.save
    assert @submission.reload.pending?
  end

  test "returning needs feedback but no call on journals; rejecting needs an admin" do
    refute review(verdict: "returned").save
    assert review(verdict: "returned", feedback: "Add the gerbers", journals: {}).save
    assert @submission.reload.returned?
    assert_nil @submission.grant_payout

    @submission = submit_design(projects(:station))
    refute review(verdict: "rejected", feedback: "Copied").save
    @reviewer.update!(roles: %w[user admin])
    assert review(verdict: "rejected", feedback: "Copied").save
  end

  test "returning keeps the calls for the next review but applies none of them" do
    journal = journals(:first)
    xp_before = journal.xp_entry.amount
    half = calls(deflate: journal).merge(@journals.last.public_id => { "approved_minutes" => 1 })

    assert review(verdict: "returned", feedback: "Add the gerbers", journals: half).save

    call = @submission.journal_reviews.find_by(journal:)
    assert_equal [ journal.duration_minutes / 3, "Idle or AFK time" ], [ call.approved_minutes, call.reason ]
    refute @submission.journal_reviews.exists?(journal: @journals.last), "a call without a reason isn't kept"
    assert_nil journal.reload.reviewed_minutes
    assert_equal xp_before, journal.xp_entry.reload.amount
    assert @submission.bom_items.reload.all? { it.verdict.nil? }, "returning funds and records no part"
    assert_nil @submission.reload.approved_cents

    again = submit_design(projects(:station))
    earlier = ReviewPageProps.new(again, reviewer: @reviewer, claimed: true, can: {}).props[:journals].find { it["id"] == journal.public_id }["earlier"]
    assert_equal journal.duration_minutes / 3, earlier[:approved_minutes]
  end

  test "AI-generated journals can only be rejected for good, by any design reviewer, and count no time" do
    journal = journals(:first)
    assert journal.xp_entry.amount.positive?

    %w[approved returned].each do |verdict|
      marked = review(verdict:, feedback: "Write your own journals", ai: true)
      refute marked.save
      assert_match "rejected for good", marked.errors[:base].join
    end

    marked = SubmissionReview.new(@submission, reviewer: @reviewer, verdict: "rejected", ai: "true", cut: "30",
      internal_reason: "AI-generated journals: all of them", feedback: "AI-generated journals are not allowed.")
    assert marked.save, marked.errors.full_messages.to_sentence
    @submission.reload

    assert @submission.rejected?
    assert @submission.ai_generated
    assert_nil @submission.internal_deflated_minutes
    assert_nil @submission.approved_cents
    assert @journals.all? { |j| j.reload.reviewed_minutes.zero? }
    assert_equal [ JournalReview::AI_GENERATED ], @submission.journal_reviews.distinct.pluck(:reason)
    assert journal.xp_entry.reload.discarded?
    assert_no_enqueued_jobs only: YswsSubmissionJob
  end

  test "rejecting for AI-generated journals takes the XP of one an earlier review already cut to nothing" do
    journal = journals(:first)
    journal.update_column(:reviewed_minutes, 0)
    journal.xp_entry.update!(amount: 1, discarded_at: nil)

    assert SubmissionReview.new(@submission, reviewer: @reviewer, verdict: "rejected", ai: true,
      internal_reason: "AI-generated journals: all", feedback: "Not allowed").save
    assert journal.xp_entry.reload.discarded?
  end

  test "a rejection can be reopened from the console, giving back the time, the XP and the queue spot" do
    journal = journals(:first)
    xp_before = journal.xp_entry.amount
    admin = users(:admin)
    assert SubmissionReview.new(@submission, reviewer: @reviewer, verdict: "rejected", ai: true,
      internal_reason: "AI-generated journals: all", feedback: "Not allowed").save
    assert journal.xp_entry.reload.discarded?

    SubmissionReview.reopen(@submission.reload, by: admin)
    @submission.reload

    assert @submission.pending?
    refute @submission.ai_generated
    assert_nil @submission.feedback
    assert_empty @submission.journal_reviews
    assert @journals.all? { |j| j.reload.reviewed_minutes.nil? }
    refute journal.xp_entry.reload.discarded?
    assert_equal xp_before, journal.xp_entry.amount
    note = @submission.project.reviewer_notes.last
    assert_equal admin, note.user
    assert_match "AI-generated journals: all", note.body
    assert_equal @submission, SubmissionReview.next_for(admin)

    assert_raises(ArgumentError) { SubmissionReview.reopen(@submission, by: admin) }
  end

  test "an HCA identity that can't be fetched leaves the YSWS row without the person's details, as Fallout does" do
    @submission.user.update_column(:hca_token, "expired")
    original = HCA.method(:identity)
    HCA.define_singleton_method(:identity) { |_token| raise Faraday::ConnectionFailed, "down" }
    assert_equal({}, YswsSubmission.identity_of(@submission.user))
  ensure
    HCA.define_singleton_method(:identity, original)
  end

  test "an approved design is queued for YSWS, and nothing is sent until the table is configured" do
    assert_enqueued_with(job: YswsSubmissionJob, args: [ @submission ]) { assert review.save }
    refute YswsSubmission.configured?
    assert_nil YswsSubmission.upload(@submission.reload)

    fields = YswsSubmission.fields(@submission, identity: { "first_name" => "Ada", "addresses" => [ { "line_1" => "1 Main St", "primary" => true } ] })
    assert_equal [ "Ada", "1 Main St", @submission.repo_url ], fields.values_at("First Name", "Address (Line 1)", "Code URL")
    assert_equal (@submission.internal_minutes / 60.0).round(1), fields["Optional - Override Hours Spent"]
    assert_match "counted by the design review", fields["Optional - Override Hours Spent Justification"]
  end

  test "an internal cut lowers only the hours staff report, never the journals, XP or funding" do
    journal = journals(:first)
    xp_before = journal.xp_entry.amount
    counted = @journals.sum(&:duration_minutes)

    assert review(cut: "45").save
    @submission.reload

    assert_equal 45, @submission.internal_deflated_minutes
    assert_equal counted - 45, @submission.internal_minutes
    assert_nil journal.reload.reviewed_minutes
    assert_equal xp_before, journal.xp_entry.reload.amount
    assert_equal @submission.bom_items.sum(&:requested_cents), @submission.approved_cents
    refute_includes SubmissionSerializer.new(@submission).to_h.keys, "internal_deflated_minutes"
  end

  test "an internal cut is whole minutes within the time that counts, and returning drops it" do
    counted = @journals.sum(&:duration_minutes)
    [ "0", "abc", (counted + 1).to_s ].each do |cut|
      marked = review(cut:)
      refute marked.save
      assert marked.errors[:cut].any?, cut
    end

    deflated = review(journals: calls(deflate: journals(:first)), cut: (counted - 1).to_s)
    refute deflated.save, "the cut is checked against the time left after journal cuts"

    assert review(verdict: "returned", feedback: "Add the gerbers", journals: {}, cut: "30").save
    assert_nil @submission.reload.internal_deflated_minutes
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
end
