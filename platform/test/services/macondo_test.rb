require "test_helper"

class MacondoTest < ActiveSupport::TestCase
  test "reads a project link" do
    assert_equal "6425", Macondo.ref_from("https://macondo.hackclub.com/projects/6425")
    assert_nil Macondo.ref_from("https://macondo.hackclub.com/explore")
    assert_nil Macondo.ref_from("https://stardance.hackclub.com/projects/6425")
  end

  test "reads the project, its journals, and the hours from its latest ship" do
    project = {
      name: "Wizard", description: "A game", repository_url: "https://github.com/x/wizard", demo_url: nil, type: "software",
      owner: { username: "Hades", image: "https://x.test/a.png", slack_id: "U0OWNER" },
      journals: [
        { id: 2, short_brief: "Day two", long_brief: "Fixed it.\n\n![video](https://cdn.hackclub.com/a/run.mov)", hours: 0, created_at: "2026-08-02T10:00:00Z", archived: false, author_slack_id: "U0OWNER" },
        { id: 1, short_brief: "", long_brief: "Started.", hours: 1.5, created_at: "2026-08-01T10:00:00Z", archived: false, author_slack_id: "U0FRIEND" },
        { id: 3, short_brief: "Old", long_brief: "Gone.", hours: 4, created_at: "2026-08-03T10:00:00Z", archived: true, author_slack_id: "U0OWNER" }
      ]
    }
    ships = [ { status: "rejected", hackatime_hours: 30.5, created_at: "2026-08-20T00:00:00Z" }, { status: "shipped", hackatime_hours: 20, created_at: "2026-05-01T00:00:00Z" } ]
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/api/projects/6425") { [ 200, {}, project.to_json ] }
    stubs.get("/api/projects/6425/ships") { [ 200, {}, ships.to_json ] }

    snapshot = with_macondo(stubs) { Macondo.project("6425") }
    assert_equal [ "Wizard", "https://github.com/x/wizard", false, "rejected", 1830 ], snapshot.values_at("title", "repo_url", "hardware", "status", "minutes")
    assert_equal %w[U0OWNER U0FRIEND], snapshot["author_slack_ids"]
    assert_equal [ [ "1", 90, "Started." ], [ "2", 0, "**Day two**\n\nFixed it.\n\n[Video](https://cdn.hackclub.com/a/run.mov)" ] ],
                 snapshot["entries"].map { it.values_at("ref", "minutes", "body") }
  end

  test "a missing project is an error" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/api/projects/1") { [ 404, {}, { error: true }.to_json ] }

    assert_raises(Macondo::Error) { with_macondo(stubs) { Macondo.project("1") } }
  end

  private

  def with_macondo(stubs, &) = stub_method(Macondo, :connection, Faraday.new { it.adapter :test, stubs }, &)
end
