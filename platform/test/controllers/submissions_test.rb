require "test_helper"

class SubmissionsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    sign_in_as users(:member)
    Flipper.enable(SubmissionsController::FLAG)
    projects(:station).journals.kept.needing_hours.update_all(duration_minutes: 30)
  end

  def params_for(snapshot, blob)
    { submission: { snapshot_id: snapshot.public_id, made_with: %w[pcb], note: "", screenshots: [ blob.signed_id ], items: bom_rows } }
  end

  def upload = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("png"), filename: "r.png", content_type: "image/png", metadata: { Journal::UPLOADER_KEY => users(:member).id })

  test "the project page offers it, and submitting puts it in the queue" do
    props = inertia_props(project_path(projects(:station)), "Projects/Show")
    assert props["can"]["submit"]
    assert_nil props["submission"]

    post project_submissions_path(projects(:station)), params: params_for(read_snapshot(projects(:station)), upload)
    assert_redirected_to project_path(projects(:station))

    props = inertia_props(project_path(projects(:station)), "Projects/Show")
    assert_equal [ "pending", 700 ], props["submission"].values_at("status", "requested_cents")
    refute props["can"]["submit"]
    assert props["can"]["withdraw"]
    refute props["submission"].key?("internal_reason"), "reviewers' notes stay on the review side"
  end

  test "failed checks come back as errors" do
    snapshot = read_snapshot(projects(:station))
    post project_submissions_path(projects(:station)), params: { submission: { snapshot_id: snapshot.public_id, items: bom_rows } }, headers: { "HTTP_REFERER" => project_path(projects(:station)) }
    assert_redirected_to project_path(projects(:station))
    assert_equal 0, Submission.count
  end

  test "off without the flag, and only for the team" do
    Flipper.disable(SubmissionsController::FLAG)
    refute inertia_props(project_path(projects(:station)), "Projects/Show")["can"]["submit"]
    post project_submissions_path(projects(:station)), params: params_for(read_snapshot(projects(:station)), upload)
    assert_equal 0, Submission.count

    Flipper.enable(SubmissionsController::FLAG)
    sign_in_as users(:newcomer)
    post project_submissions_path(projects(:station)), params: params_for(read_snapshot(projects(:station), users(:member)), upload)
    assert_equal 0, Submission.count
  end

  test "taking it back" do
    submission = submit_design(projects(:station))
    delete submission_path(submission)
    assert submission.reload.withdrawn?
  end

  test "the popup's steps: reading the repo, the CSV and the checks" do
    post project_repo_snapshots_path(projects(:station)), params: { url: "github.com/someone/thing" }, as: :json
    assert_response :success
    assert_equal [ "pending", "https://github.com/someone/thing" ], response.parsed_body.values_at("status", "url")
    assert_enqueued_jobs 1, only: RepoSnapshotJob

    post project_repo_snapshots_path(projects(:station)), params: { url: "https://169.254.169.254/latest/meta" }, as: :json
    assert_response :unprocessable_content

    get repo_snapshot_path(RepoSnapshot.last), as: :json
    assert_response :success

    post bom_imports_path, params: { csv: "Part,Qty,Price,Link\nLED,3,$0.10,https://x.com\n" }, as: :json
    assert_equal [ "LED", 3, 30 ], response.parsed_body["items"].first.values_at("name", "quantity", "total_cents")

    post project_submission_check_path(projects(:station)), params: { snapshot_id: read_snapshot(projects(:station)).public_id, made_with: %w[pcb], screenshots: 1, items: bom_rows }, as: :json
    assert_equal [], response.parsed_body["checks"].select { it["status"] == "fail" }
  end

  test "someone off the team can't read another project's repo checks" do
    snapshot = read_snapshot(projects(:station))
    sign_in_as users(:newcomer)
    get repo_snapshot_path(snapshot), as: :json
    assert_response :redirect
  end
end
