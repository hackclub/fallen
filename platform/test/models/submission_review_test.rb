require "test_helper"

class SubmissionReviewTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @submission = submit_design(projects(:station))
    # An admin's decision applies straight away; a design reviewer's waits for sign-off (tests below).
    @reviewer = users(:admin)
    @reviewer.update!(roles: %w[user design_reviewer admin])
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
    @reviewer.update!(roles: %w[user design_reviewer])
    refute review(verdict: "rejected", feedback: "Copied").save
    @reviewer.update!(roles: %w[user admin])
    assert review(verdict: "rejected", feedback: "Copied").save
  end

  test "a design reviewer's decision is held for an admin: nothing applies until it's signed off" do
    @reviewer.update!(roles: %w[user design_reviewer])
    journal = journals(:first)
    xp_before = journal.xp_entry.amount

    held = review(journals: calls(deflate: journal))
    assert held.save
    assert held.proposed?
    @submission.reload
    assert @submission.pending?
    assert @submission.awaiting_sign_off?
    assert_equal @reviewer, @submission.proposed_by
    assert_nil @submission.grant_payout
    assert_nil journal.reload.reviewed_minutes
    assert_equal xp_before, journal.xp_entry.reload.amount
    assert_not_includes Submission.queued, @submission
    assert_no_enqueued_jobs only: SubmissionDecidedJob
    refute review.save, "a second decision can't replace one waiting for sign-off"

    admin = users(:newcomer)
    admin.update!(roles: %w[user admin])
    assert SubmissionReview.sign_off(@submission, admin, proposed_at: @submission.proposed_at).save
    @submission.reload
    assert @submission.approved?
    assert_equal @reviewer, @submission.reviewer
    assert_nil @submission.proposed_review
    assert_equal @submission.bom_items.sum(&:requested_cents), @submission.grant_payout.amount_cents
    assert_equal 30, journal.reload.reviewed_minutes
    assert_operator journal.xp_entry.reload.amount, :<, xp_before
    assert_enqueued_jobs 1, only: SubmissionDecidedJob
    assert_equal "Checked and signed off #{@reviewer.display_name}'s decision (approved).", @submission.project.reviewer_notes.last.body
    assert_equal admin, @submission.project.reviewer_notes.last.user
  end

  test "an admin can change a held decision as they sign it off: it stays the reviewer's, and the note keeps what they wrote" do
    @reviewer.update!(roles: %w[user design_reviewer])
    journal = journals(:first)
    assert review(feedback: "Nice board").save
    admin = users(:newcomer).tap { it.update!(roles: %w[user admin]) }

    edits = { verdict: "returned", feedback: "Add the gerbers", internal_reason: "Looks right", rubric: Submission::RUBRIC.keys.index_with { "yes" },
              journals: calls(deflate: journal) }
    assert SubmissionReview.sign_off(@submission.reload, admin, proposed_at: @submission.proposed_at, edits:).save
    @submission.reload
    assert @submission.returned?
    assert_equal @reviewer, @submission.reviewer
    assert_equal "Add the gerbers", @submission.feedback
    assert_equal @reviewer, @submission.journal_reviews.find_by!(journal:).reviewer
    notes = @submission.project.reviewer_notes.order(:id).last(2)
    assert_equal [ admin ], notes.map(&:user).uniq
    assert_equal [ "Checked and signed off #{@reviewer.display_name}'s decision (returned), changing the decision (was approved), the feedback, and 1 journal's time.",
                   "#{@reviewer.display_name}'s feedback, before the sign-off: Nice board" ], notes.map(&:body)
  end

  test "signing off a returned decision unchanged notes no changes, and long wording the admin replaced is kept whole" do
    @reviewer.update!(roles: %w[user design_reviewer])
    long = "Add the gerbers. " * 200
    assert review(verdict: "returned", feedback: long, journals: {}).save
    admin = users(:newcomer).tap { it.update!(roles: %w[user admin]) }

    same = { verdict: "returned", feedback: long, internal_reason: "Looks right", rubric: Submission::RUBRIC.keys.index_with { "yes" },
             journals: @journals.to_h { [ it.public_id, { "approved_minutes" => it.duration_minutes, "reason" => "Other" } ] } }
    signing = SubmissionReview.sign_off(@submission.reload, admin, proposed_at: @submission.proposed_at, edits: same)
    assert_equal [ "Checked and signed off #{@reviewer.display_name}'s decision (returned)." ], signing.send(:sign_off_notes, @journals),
      "journals the reviewer left at full time, and a reason on one that isn't cut, are no change"

    signing = SubmissionReview.sign_off(@submission, admin, proposed_at: @submission.proposed_at, edits: same.merge(feedback: "Short"))
    assert signing.save
    notes = @submission.project.reviewer_notes.order(:id).last(3).map(&:body)
    assert_match "changing the feedback", notes.first
    assert_equal "#{@reviewer.display_name}'s feedback, before the sign-off: #{long.strip}", notes.drop(1).join
  end

  test "an admin signing off can reject or take an internal cut that the reviewer couldn't" do
    @reviewer.update!(roles: %w[user design_reviewer])
    assert review.save
    admin = users(:newcomer).tap { it.update!(roles: %w[user admin]) }

    edits = { verdict: "approved", feedback: "", internal_reason: "Looks right", rubric: Submission::RUBRIC.keys.index_with { "yes" }, journals: calls, cut: 10 }
    assert SubmissionReview.sign_off(@submission.reload, admin, proposed_at: @submission.proposed_at, edits:).save
    assert_equal 10, @submission.reload.internal_deflated_minutes
    assert_match "the internal cut (was none)", @submission.project.reviewer_notes.last.body

    @submission = submit_design(projects(:unlinked))
    @journals = SubmissionReview.journals_for(@submission).to_a
    assert review(journals: calls).save
    edits = edits.merge(journals: calls, verdict: "rejected", feedback: "Copied", cut: nil)
    assert SubmissionReview.sign_off(@submission.reload, admin, proposed_at: @submission.proposed_at, edits:).save
    assert @submission.reload.rejected?
    assert_equal @reviewer, @submission.reviewer
  end

  test "an admin on the team can't sign off, and a proposer who lost the role can't be signed off" do
    @reviewer.update!(roles: %w[user design_reviewer])
    assert review.save
    teammate = users(:member).tap { it.update!(roles: %w[user admin]) }
    refute (signing = SubmissionReview.sign_off(@submission, teammate, proposed_at: @submission.proposed_at)).save
    assert_includes signing.errors[:base], "You can't sign off a project you're on"

    admin = users(:newcomer).tap { it.update!(roles: %w[user admin]) }
    @reviewer.update!(roles: %w[user])
    refute (signing = SubmissionReview.sign_off(@submission.reload, admin, proposed_at: @submission.proposed_at)).save
    assert_match "no longer a design reviewer", signing.errors[:base].to_sentence
    assert @submission.reload.awaiting_sign_off?
    assert_nil @submission.grant_payout
  end

  test "a sign-off loaded before someone sent the decision back, or before a new one, applies nothing" do
    @reviewer.update!(roles: %w[user design_reviewer])
    assert review.save
    admin = users(:newcomer).tap { it.update!(roles: %w[user admin]) }

    stale = SubmissionReview.sign_off(@submission, admin, proposed_at: @submission.proposed_at)
    assert SubmissionReview.send_back(Submission.find(@submission.id), admin)
    refute stale.save
    assert_includes stale.errors[:base], "It was sent back or changed since you opened it"
    assert @submission.reload.pending?
    assert_nil @submission.grant_payout

    assert review(verdict: "returned", feedback: "Add the gerbers").save
    stale = SubmissionReview.sign_off(@submission, admin, proposed_at: @submission.proposed_at)
    Submission.find(@submission.id).update!(proposed_at: 1.minute.from_now)
    refute stale.save, "a newer proposal is not the one the admin read"
    assert @submission.reload.awaiting_sign_off?
  end

  test "an admin can send a held decision back to the queue without applying it" do
    @reviewer.update!(roles: %w[user design_reviewer])
    assert review(verdict: "returned", feedback: "Add the gerbers").save

    admin = users(:newcomer)
    admin.update!(roles: %w[user admin])
    assert SubmissionReview.send_back(@submission, admin)
    @submission.reload
    assert @submission.pending?
    refute @submission.awaiting_sign_off?
    assert_includes Submission.queued, @submission
    assert_match "Sent back", @submission.project.reviewer_notes.last.body
    refute SubmissionReview.send_back(@submission, admin), "nothing left to send back"
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

    fields = stub_method(Github, :commit_range, [ Time.utc(2026, 10, 1), Time.utc(2026, 10, 9) ]) do
      YswsSubmission.fields(@submission, identity: { "first_name" => "Ada", "addresses" => [ { "line_1" => "1 Main St", "primary" => true } ] })
    end
    assert_equal [ "Ada", "1 Main St", @submission.repo_url ], fields.values_at("First Name", "Address (Line 1)", "Code URL")
    assert_equal (@submission.internal_minutes / 60.0).round(1), fields["Optional - Override Hours Spent"]
    refute fields.key?("Optional - Override Hours Spent Justification"), "the table joins it from the machine and manual parts"

    text = fields["Machine Justification"]
    assert_match "This is the design submission of \"#{@submission.project.title}\" for Fallen", text
    assert_match "Ada logged their time in #{@journals.size} journals", text
    assert_match "commits from Oct 1, 2026 to Oct 9, 2026", text
    @journals.each { assert_match "#journal-#{it.public_id}", text }
    assert_match "signed off by Fallen staff member #{@submission.reviewer.display_name.split.first}", text
    assert text.end_with?("are appropriate for Unified:")
  end

  test "the YSWS justification names the admin who signed off, and each journal's cut with its reason" do
    @reviewer.update!(roles: %w[user design_reviewer])
    admin = users(:newcomer)
    admin.update!(roles: %w[user admin])
    journal = @journals.first
    deflated = calls.merge(journal.public_id => { "approved_minutes" => journal.duration_minutes - 30, "reason" => "Idle or AFK time", "note" => "Long gap mid-session" })
    assert review(journals: deflated).save
    assert SubmissionReview.sign_off(@submission.reload, admin, proposed_at: @submission.proposed_at).save

    text = YswsJustification.render(@submission.reload, first_name: "Ada", commits: nil)
    assert_equal admin, @submission.signed_off_by
    assert_match "approved on", text
    assert_match "by #{@reviewer.display_name}", text
    assert_match "It then went through a second sign-off by #{admin.display_name}.", text
    assert_match "0.5h was deflated", text
    assert_match "Idle or AFK time: Long gap mid-session", text
    assert_match "The repository: #{@submission.repo_url}", text
    assert_match "staff member #{admin.display_name.split.first},", text
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
