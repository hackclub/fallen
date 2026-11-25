require "test_helper"

class ReviewTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @submission = submit_design(projects(:station))
    @reviewer = users(:newcomer)
    @reviewer.update!(roles: %w[user design_reviewer])
  end

  def decision(verdict: "approved", feedback: "")
    journals = SubmissionReview.journals_for(@submission).to_h { [ it.public_id, { approved_minutes: it.duration_minutes } ] }
    { review: { verdict:, feedback:, internal_reason: "Fine", rubric: Submission::RUBRIC.keys.index_with { "yes" }, journals: } }
  end

  test "people without the role don't see the queue" do
    sign_in_as users(:member)
    get review_submissions_path
    assert_response :not_found
  end

  test "a design reviewer works the queue: next claims it, the page shows the evidence, deciding moves on" do
    sign_in_as @reviewer
    rows = load_deferred(review_submissions_path, "Review/Submissions/Index", "submissions", "pagy", "counts")
    assert_equal [ @submission.public_id ], rows["submissions"].pluck("id")
    assert_equal 1, rows["counts"]["queue"]

    get review_next_path
    assert_redirected_to review_submission_path(@submission)
    assert_equal @reviewer.id, @submission.reload.claimed_by_id

    props = inertia_props(review_submission_path(@submission), "Review/Submissions/Show")
    assert props["claimed"]
    assert props["can"]["decide"]
    refute props["can"]["reject"]
    refute props["can"]["cut"]
    assert_equal SubmissionReview.journals_for(@submission).count, props["journals"].size
    assert_equal "board.kicad_pcb", props["repo"]["paths"].second

    post heartbeat_review_submission_path(@submission), as: :json
    assert response.parsed_body["held"]

    patch review_submission_path(@submission), params: decision
    assert_redirected_to review_next_path
    assert @submission.reload.awaiting_sign_off?, "a design reviewer's decision waits for an admin"
    assert_equal @reviewer, @submission.proposed_by
  end

  test "only an admin's internal cut is taken; a design reviewer's is refused" do
    params = decision
    params[:review][:cut] = "30"

    sign_in_as @reviewer
    get review_next_path
    patch review_submission_path(@submission), params: params
    assert_redirected_to root_path
    assert @submission.reload.pending?

    @reviewer.update!(roles: %w[user admin])
    patch review_submission_path(@submission), params: params
    assert_redirected_to review_next_path
    assert_equal 30, @submission.reload.internal_deflated_minutes
  end

  test "a design reviewer can reject for AI-generated journals, and nothing else" do
    sign_in_as @reviewer
    get review_next_path
    patch review_submission_path(@submission), params: decision(verdict: "rejected", feedback: "Copied")
    assert_redirected_to root_path
    assert @submission.reload.pending?

    patch review_submission_path(@submission), params: { review: { verdict: "rejected", ai: true, internal_reason: "AI-generated journals: all", feedback: "Not allowed" } }
    assert_redirected_to review_next_path
    assert @submission.reload.awaiting_sign_off?, "held for an admin to sign off"
    refute inertia_props(review_submission_path(@submission), "Review/Submissions/Show")["can"]["decide"]
  end

  test "an admin signs off a design reviewer's decision from /admin/sign-offs, or sends it back" do
    sign_in_as @reviewer
    get review_next_path
    patch review_submission_path(@submission), params: decision
    assert_redirected_to review_next_path
    assert_match "sign off", flash[:notice]
    assert @submission.reload.awaiting_sign_off?

    get admin_sign_offs_path
    assert_response :not_found
    patch admin_sign_off_path(@submission)
    assert_response :not_found

    admin = users(:admin)
    admin.update!(roles: %w[user admin])
    sign_in_as admin
    rows = load_deferred(admin_sign_offs_path, "Admin/SignOffs/Index", "submissions", "pagy")
    assert_equal [ @submission.public_id ], rows["submissions"].pluck("id")
    assert_equal "approved", rows["submissions"].first["verdict"]
    assert_equal @reviewer.public_id, rows["submissions"].first.dig("proposed_by", "id")

    patch admin_sign_off_path(@submission), params: { proposed_at: rows["submissions"].first["proposed_at"] }
    assert_redirected_to admin_sign_offs_path
    assert @submission.reload.approved?
    assert_equal @reviewer, @submission.reviewer
    assert @submission.grant_payout

    other = submit_design(projects(:unlinked))
    SubmissionReview.new(other, reviewer: @reviewer, verdict: "returned", feedback: "More photos", internal_reason: "Thin",
      rubric: Submission::RUBRIC.keys.index_with { "yes" }).save
    sign_in_as @reviewer
    rows = load_deferred(review_submissions_path(tab: "sign_off"), "Review/Submissions/Index", "submissions", "pagy", "counts")
    assert_equal [ other.public_id ], rows["submissions"].pluck("id"), "reviewers can find what's waiting on an admin"
    assert_equal @reviewer.public_id, rows["submissions"].first.dig("proposed_by", "id")
    assert_equal 1, rows["counts"]["sign_off"]

    sign_in_as admin
    delete admin_sign_off_path(other)
    assert_redirected_to admin_sign_offs_path
    assert_match "back in the queue", flash[:notice]
    assert other.reload.pending?
    refute other.awaiting_sign_off?

    SubmissionReview.new(other, reviewer: @reviewer, verdict: "returned", feedback: "More photos", internal_reason: "Thin",
      rubric: Submission::RUBRIC.keys.index_with { "yes" }).save
    assert SubmissionReview.sign_off(other.reload, admin, proposed_at: other.proposed_at).save
    delete admin_sign_off_path(other)
    assert other.reload.returned?, "nothing left to send back: the decision stands"
    assert_nil other.proposed_at
  end

  test "signing off from a page loaded before the decision was sent back and proposed again applies nothing" do
    sign_in_as @reviewer
    get review_next_path
    patch review_submission_path(@submission), params: decision(verdict: "returned", feedback: "More photos")
    admin = users(:admin).tap { it.update!(roles: %w[user admin]) }
    sign_in_as admin
    read = load_deferred(admin_sign_offs_path, "Admin/SignOffs/Index", "submissions", "pagy")["submissions"].first
    assert_equal "returned", read["verdict"]

    assert SubmissionReview.send_back(@submission.reload, admin)
    sign_in_as @reviewer
    get review_next_path
    patch review_submission_path(@submission), params: decision
    assert @submission.reload.awaiting_sign_off?

    sign_in_as admin
    patch admin_sign_off_path(@submission), params: { proposed_at: read["proposed_at"] }
    assert_redirected_to admin_sign_offs_path
    assert_match "sent back or changed", flash[:alert]
    assert @submission.reload.awaiting_sign_off?, "the approval the admin never saw stays waiting"
    assert_nil @submission.grant_payout

    patch admin_sign_off_path(@submission)
    assert_match "sent back or changed", flash[:alert], "no proposal named: nothing applies"
    assert @submission.reload.awaiting_sign_off?
  end

  test "an admin signs off like a review session: next claims a held decision, they see and edit it, and it stays the reviewer's" do
    sign_in_as @reviewer
    get review_next_path
    patch review_submission_path(@submission), params: decision

    admin = users(:admin).tap { it.update!(roles: %w[user admin]) }
    other_admin = User.create!(email: "second@example.com", display_name: "Second Admin", hca_id: "hca_second", roles: %w[user admin], pet: "lulu")
    sign_in_as admin
    get review_next_sign_off_path
    assert_redirected_to review_submission_path(@submission)
    assert_equal admin, @submission.reload.claimed_by

    props = inertia_props(review_submission_path(@submission), "Review/Submissions/Show")
    assert props["claimed"]
    assert props["can"]["sign_off"]
    assert props["can"]["decide"]
    assert_equal "approved", props.dig("proposal", "data", "verdict")
    assert_equal @reviewer.public_id, props.dig("proposal", "by", "id")

    patch draft_review_submission_path(@submission), params: { draft: { feedback: "x" } }, as: :json
    assert_redirected_to root_path, "an admin's edits don't replace the reviewer's own draft"

    refute SubmissionReview.claim(@submission, other_admin), "one admin at a time"

    post heartbeat_review_submission_path(@submission, sign_off: "1"), as: :json
    assert response.parsed_body["held"]
    assert_nil SubmissionReview.next_for(other_admin, signing_off: true)

    page = review_submission_path(@submission)
    patch admin_sign_off_path(@submission), params: decision(verdict: "returned").merge(proposed_at: props["proposal"]["at"]), headers: { "HTTP_REFERER" => page }
    assert_redirected_to page
    assert @submission.reload.awaiting_sign_off?, "a broken edit applies nothing"

    patch admin_sign_off_path(@submission), params: decision(verdict: "returned", feedback: "More photos").merge(proposed_at: props["proposal"]["at"])
    assert_redirected_to review_next_sign_off_path
    assert @submission.reload.returned?
    assert_equal @reviewer, @submission.reviewer
    assert_equal "More photos", @submission.feedback
    assert_match "changing the decision (was approved)", @submission.project.reviewer_notes.order(:id).last(2).first.body

    get review_next_sign_off_path
    assert_redirected_to admin_sign_offs_path, "back to the recap when there's nothing left"

    sign_in_as @reviewer
    get review_next_sign_off_path
    assert_redirected_to root_path
  end

  test "a sign-off page sent back to the queue under it stops holding it on its next heartbeat" do
    sign_in_as @reviewer
    get review_next_path
    patch review_submission_path(@submission), params: decision
    admin = users(:admin).tap { it.update!(roles: %w[user admin]) }
    sign_in_as admin
    get review_next_sign_off_path
    assert_equal admin, @submission.reload.claimed_by

    assert SubmissionReview.send_back(@submission, users(:newcomer).tap { it.update!(roles: %w[user design_reviewer admin]) })
    post heartbeat_review_submission_path(@submission, sign_off: "1"), as: :json
    refute response.parsed_body["held"]
    assert_nil @submission.reload.claimed_by, "it's back in the queue for anyone"
  end

  test "a review missing something comes back with errors, and only admins reject" do
    sign_in_as @reviewer
    get review_submission_path(@submission)
    patch review_submission_path(@submission), params: decision(verdict: "returned"), headers: { "HTTP_REFERER" => review_submission_path(@submission) }
    assert @submission.reload.pending?

    patch review_submission_path(@submission), params: decision(verdict: "rejected", feedback: "No")
    assert @submission.reload.pending?
  end

  test "skipping lets it go, flagging takes it out of the queue, notes stay on the project" do
    sign_in_as @reviewer
    get review_next_path
    post release_review_submission_path(@submission)
    assert_nil @submission.reload.claimed_by_id
    assert_redirected_to review_next_path(skip: @submission.public_id)

    post review_submission_notes_path(@submission), params: { body: "Same as their Blueprint project" }
    assert_equal [ "Same as their Blueprint project" ], projects(:station).reviewer_notes.pluck(:body)

    post flag_review_submission_path(@submission), params: { reason: "Copied from a guide" }
    assert @submission.reload.flagged_at
    assert_empty Submission.queued
    post unflag_review_submission_path(@submission)
    assert @submission.reload.flagged_at, "only admins clear a flag"
  end

  test "the review so far is saved on the server, carried on by the next person, and cleared by the decision" do
    sign_in_as @reviewer
    get review_next_path
    draft = { rubric: { complete: "yes" }, feedback: "Nice work so far", internal: "", journals: {}, bom: {}, extra: "dropped" }
    patch draft_review_submission_path(@submission), params: { draft: }, as: :json
    assert response.parsed_body["saved"]
    assert_equal({ "complete" => "yes" }, @submission.reload.review_draft["rubric"])
    assert_not @submission.review_draft.key?("extra")
    assert_not @submission.review_draft.key?("bom"), "parts take no calls any more"
    assert_equal @reviewer, @submission.review_draft_by

    other = users(:admin)
    sign_in_as other
    patch draft_review_submission_path(@submission), params: { draft: { feedback: "overwrite" } }, as: :json
    assert_response :conflict
    assert_equal "Nice work so far", @submission.reload.review_draft["feedback"]

    @submission.update_columns(claim_expires_at: 1.minute.ago)
    props = inertia_props(review_submission_path(@submission), "Review/Submissions/Show")
    assert_equal [ "Nice work so far", @reviewer.public_id ], [ props.dig("draft", "data", "feedback"), props.dig("draft", "by", "id") ]

    patch review_submission_path(@submission), params: decision
    assert_nil @submission.reload.review_draft
  end

  test "a reviewer can take over a submission someone left open, and the one who left it loses it" do
    away = users(:admin)
    SubmissionReview.claim(@submission, away)

    sign_in_as @reviewer
    props = inertia_props(review_submission_path(@submission), "Review/Submissions/Show")
    refute props["can"]["decide"]
    assert props["can"]["take_over"]

    post take_over_review_submission_path(@submission)
    assert_redirected_to review_submission_path(@submission)
    assert_equal @reviewer, @submission.reload.claimed_by

    sign_in_as away
    post heartbeat_review_submission_path(@submission), as: :json
    refute response.parsed_body["held"]
  end

  test "nobody reviews their own project" do
    users(:member).update!(roles: %w[user design_reviewer])
    sign_in_as users(:member)
    refute inertia_props(review_submission_path(@submission), "Review/Submissions/Show")["can"]["decide"]
    get review_next_path
    assert_redirected_to review_submissions_path
  end
end
