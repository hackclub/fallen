require "test_helper"

class FalloutTest < ActiveSupport::TestCase
  test "reads a project link, or the bulletin board opened on one" do
    assert_equal "3827", Fallout.ref_from("https://fallout.hackclub.com/projects/3827")
    assert_equal "3827", Fallout.ref_from("https://fallout.hackclub.com/bulletin_board?project=3827")
    assert_nil Fallout.ref_from("https://fallout.hackclub.com/bulletin_board")
  end

  test "asks for the project as an Inertia request, with the app's asset version" do
    props = {
      project: { name: "Prism CNC", description: "A CNC", repo_link: "https://github.com/x/cnc", demo_link: nil, user_display_name: "Logan", time_logged: 91_440 },
      ships: [ { status: "approved", created_at_iso: "2026-06-15T00:00:00Z" } ],
      journal_entries: [
        { id: 2, content_html: "<p>Wired <em>it</em>.</p><p><img src=\"/user-attachments/blobs/proxy/a/w.png\"></p>", time_logged: 1920, created_at_iso: "2026-06-14T15:46:49Z",
          images: [ "https://fallout.hackclub.com/user-attachments/blobs/proxy/b/d.png" ] },
        { id: 1, content_html: "<ul><li>Planned</li></ul>", time_logged: 0, created_at_iso: "2026-03-14T00:00:00Z", images: [] }
      ]
    }
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/") { [ 200, {}, %(<script data-page="app" type="application/json">{"component":"landing/index","props":{},"version":"v1"}</script>) ] }
    stubs.get("/projects/3827") do |env|
      assert_equal [ "true", "v1" ], env.request_headers.values_at("X-Inertia", "X-Inertia-Version")
      [ 200, {}, { component: "projects/show", props: props }.to_json ]
    end

    snapshot = with_fallout(stubs) { Fallout.project("3827") }
    assert_equal [ "Prism CNC", "approved", true, 1524 ], snapshot.values_at("title", "status", "hardware", "minutes")
    assert_equal [ [ "1", 0, "- Planned" ], [ "2", 32, "Wired *it*.\n\n![](https://fallout.hackclub.com/user-attachments/blobs/proxy/a/w.png)" ] ],
                 snapshot["entries"].map { it.values_at("ref", "minutes", "body") }
    assert_equal [ "https://fallout.hackclub.com/user-attachments/blobs/proxy/b/d.png" ], snapshot.dig("entries", 1, "images")
  end

  private

  def with_fallout(stubs, &) = stub_method(Fallout, :connection, Faraday.new { it.adapter :test, stubs }, &)
end
