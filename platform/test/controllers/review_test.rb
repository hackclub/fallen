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
    bom = @submission.bom_items.to_h { [ it.public_id, { verdict: "approved" } ] }
    { review: { verdict:, feedback:, internal_reason: "Fine", rubric: Submission::RUBRIC.keys.index_with { "yes" }, journals:, bom: } }
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
    assert_equal SubmissionReview.journals_for(@submission).count, props["journals"].size
    assert_equal "board.kicad_pcb", props["repo"]["paths"].second

    post heartbeat_review_submission_path(@submission), as: :json
    assert response.parsed_body["held"]

    patch review_submission_path(@submission), params: decision
    assert_redirected_to review_next_path
    assert @submission.reload.approved?
    assert_equal @reviewer, @submission.reviewer
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
