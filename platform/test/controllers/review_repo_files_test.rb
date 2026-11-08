require "test_helper"

class ReviewRepoFilesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @submission = submit_design(projects(:station))
    @reviewer = users(:newcomer)
    @reviewer.update!(roles: %w[user design_reviewer])
  end

  def reading(callable)
    original = GitRemote.method(:read_files)
    GitRemote.define_singleton_method(:read_files) { |*args, **_| callable.(*args) }
    yield
  ensure
    GitRemote.define_singleton_method(:read_files, original)
  end

  def ask(path) = post review_submission_repo_files_path(@submission), params: { path: }, as: :json

  test "only design reviewers can ask for a file" do
    sign_in_as users(:member)
    ask "board.kicad_pcb"
    assert_response :not_found
    assert_equal 0, RepoFile.count
  end

  test "paths that aren't files in the snapshot are refused without reading anything" do
    sign_in_as @reviewer
    [ "../../etc/passwd", "/README.md", "missing.txt", "board.kicad_pcb/", "" ].each do |path|
      assert_no_enqueued_jobs { ask path }
      assert_response :not_found, path
    end
    assert_equal 0, RepoFile.count
  end

  test "the first ask queues the read, later ones poll until it's done, then it downloads as an attachment" do
    sign_in_as @reviewer
    assert_enqueued_with(job: RepoFileJob) { ask "board.kicad_pcb" }
    assert_response :accepted
    assert_equal "pending", response.parsed_body["status"]

    assert_no_enqueued_jobs { ask "board.kicad_pcb" }
    assert_response :accepted
    assert_equal 1, RepoFile.count

    read = ->(url, sha, paths) do
      assert_equal [ "https://github.com/someone/thing", "a" * 40, [ "board.kicad_pcb" ] ], [ url, sha, paths ]
      { "board.kicad_pcb" => "<script>alert(1)</script>".b }
    end
    reading(read) { perform_enqueued_jobs }

    ask "board.kicad_pcb"
    assert_response :success
    assert_equal "done", response.parsed_body["status"]
    assert_equal 25, response.parsed_body["size"]

    get response.parsed_body["url"]
    follow_redirect! while response.redirect?
    assert_response :success
    assert_equal "application/octet-stream", response.media_type
    assert_match(/\Aattachment/, response.headers["Content-Disposition"])
    assert_equal "<script>alert(1)</script>", response.body
  end

  test "a file that couldn't be read says why, and is tried again later" do
    sign_in_as @reviewer
    ask "gerbers.zip"
    reading(->(*) { raise GitRemote::Error, "The repository took too long to read" }) { perform_enqueued_jobs }

    ask "gerbers.zip"
    assert_response :success
    assert_equal({ "status" => "failed", "error" => "The repository took too long to read" }, response.parsed_body)

    travel RepoFile::RETRY_AFTER + 1.minute do
      assert_enqueued_with(job: RepoFileJob) { ask "gerbers.zip" }
      assert_response :accepted
    end
  end
end
