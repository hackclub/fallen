require "test_helper"

class StasisTest < ActiveSupport::TestCase
  test "reads a project link" do
    assert_equal "cmabc123", Stasis.ref_from("https://stasis.hackclub.com/dashboard/projects/cmabc123")
    assert_equal "cmabc123", Stasis.ref_from("https://stasis.hackclub.com/dashboard/discover/cmabc123/")
    assert_nil Stasis.ref_from("https://stasis.hackclub.com/dashboard/projects/cmabc123/session/new")
    assert_nil Stasis.ref_from("https://forge.hackclub.com/projects/710")
  end

  test "reads the project and its work sessions, whoever asks" do
    project = {
      id: "cmabc123", title: "Split keyboard", description: "Clacky", githubRepo: "https://github.com/x/kb",
      designStatus: "approved", buildStatus: "draft", user: { name: "Ada", image: "https://avatars.slack-edge.com/ada.png" }
    }
    timeline = [
      { type: "REVIEW_ACTION", at: "2026-09-03T10:00:00Z", decision: "APPROVED" },
      { type: "WORK_SESSION", at: "2026-09-02T10:00:00Z",
        session: { id: "s2", hoursClaimed: 1.5, content: "It types.", media: [
          { type: "IMAGE", url: "https://stasis.hackclub-assets.com/images/kb.png" },
          { type: "VIDEO", url: "https://stasis.hackclub-assets.com/videos/kb.mp4" }
        ] } },
      { type: "WORK_SESSION", at: "2026-09-01T10:00:00Z", session: { id: "s1", hoursClaimed: 0.25, content: nil, media: [] } }
    ]
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/api/discover/cmabc123") { [ 200, {}, project.to_json ] }
    stubs.get("/api/discover/cmabc123/timeline") { [ 200, {}, timeline.to_json ] }

    snapshot = with_stasis(stubs) { Stasis.project("cmabc123") }
    assert_equal [ "Split keyboard", "Clacky", "https://github.com/x/kb", "design approved", 2, 105 ],
                 snapshot.values_at("title", "description", "repo_url", "status", "entry_count", "minutes")
    assert_equal [ "Ada", "https://avatars.slack-edge.com/ada.png" ], snapshot["owner"].values_at("name", "avatar")
    assert_equal [ [ "s1", 15, "", [] ],
                   [ "s2", 90, "It types.\n\nVideo: https://stasis.hackclub-assets.com/videos/kb.mp4", [ "https://stasis.hackclub-assets.com/images/kb.png" ] ] ],
                 snapshot["entries"].map { it.values_at("ref", "minutes", "body", "images") }
  end

  test "a hidden or deleted project is an error" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/api/discover/gone") { [ 404, {}, { error: "Project not found" }.to_json ] }

    assert_raises(Stasis::Error) { with_stasis(stubs) { Stasis.project("gone") } }
  end

  private

  def with_stasis(stubs, &) = stub_method(Stasis, :connection, Faraday.new { it.adapter :test, stubs }, &)
end
