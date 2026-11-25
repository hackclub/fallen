require "test_helper"

class SignOffDeskTest < ActionDispatch::IntegrationTest
  MATCH = { "status" => "match", "reason" => nil, "mode" => "pcb", "matches" => [ { "repo" => "someone/board", "url" => "https://github.com/someone/board", "containment" => 1.0, "mode" => "pcb", "blocks" => [] } ] }.freeze

  setup do
    SignOffDesk.available = true
    @reviewer = users(:newcomer)
    @reviewer.update!(roles: %w[user design_reviewer])
    @admin = users(:admin)
    @admin.update!(roles: %w[user admin])
    @first = propose(submit_design(projects(:station)))
    @second = propose(submit_design(projects(:unlinked)))
  end

  def propose(submission)
    journals = SubmissionReview.journals_for(submission).to_h { [ it.public_id, { "approved_minutes" => it.duration_minutes } ] }
    assert SubmissionReview.new(submission, reviewer: @reviewer, verdict: "approved", internal_reason: "Fine",
      rubric: Submission::RUBRIC.keys.index_with { "yes" }, journals:).save
    submission.reload
  end

  test "the desk lists what waits and opens one case at a time" do
    sign_in_as @admin
    props = inertia_props(admin_sign_offs_path, "Admin/SignOffs/Desk")
    assert_equal Submission::RUBRIC, props["questions"]

    deferred = load_deferred(admin_sign_offs_path, "Admin/SignOffs/Desk", "queue", "pagy", "totals")
    assert_equal [ @first.public_id, @second.public_id ], deferred["queue"].pluck("id")
    assert_equal({ "count" => 2, "approvals_cents" => @first.requested_cents + @second.requested_cents }, deferred["totals"])

    record = load_deferred(admin_sign_offs_path, "Admin/SignOffs/Desk", "case")["case"]
    assert_equal @first.public_id, record["id"], "the one waiting longest"
    assert_equal SubmissionReview.journals_for(@first).count, record["journals"].size

    record = load_deferred(admin_sign_offs_path(id: @second.public_id), "Admin/SignOffs/Desk", "case")["case"]
    assert_equal @second.public_id, record["id"]
  end

  test "a copy match blocks approval until an admin compares the designs" do
    @first.update!(copy_check: MATCH)
    sign_in_as @admin

    patch admin_sign_off_path(@first), params: { proposed_at: @first.proposed_at.iso8601(6), next: @second.public_id }
    assert_redirected_to admin_sign_offs_path(id: @first.public_id)
    assert_match "compare the designs", flash[:alert]
    assert @first.reload.awaiting_sign_off?

    post compare_admin_sign_off_path(@first), params: { copied: false, note: "Shared starter file" }
    assert_redirected_to admin_sign_offs_path(id: @first.public_id)
    follow_redirect!
    refute @first.reload.copy_check_holds_approval?

    patch admin_sign_off_path(@first), params: { proposed_at: @first.proposed_at.iso8601(6), next: @second.public_id }
    assert_redirected_to admin_sign_offs_path(id: @second.public_id)
    assert_nil flash[:notice], "the desk shows its own confirmation"
    assert @first.reload.approved?
  end

  test "checking again needs a decision waiting on sign-off" do
    sign_in_as @admin
    post rescreen_admin_sign_off_path(@first)
    assert_equal({ "status" => "pending", "attempts" => 0 }, @first.reload.copy_check)

    sign_in_as @reviewer
    post rescreen_admin_sign_off_path(@first)
    assert_response :not_found
  end
end
