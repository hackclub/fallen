require "test_helper"

class ForgeTest < ActiveSupport::TestCase
  test "reads a project link" do
    assert_equal "710", Forge.ref_from("https://forge.hackclub.com/projects/710/")
    assert_nil Forge.ref_from("https://forge.hackclub.com/explore")
  end

  test "reads the project and its devlogs from the page's props" do
    props = {
      project: { name: "Ender press", subtitle: "A press", repo_link: "https://github.com/x/press", status: "approved",
                 members: [ { display_name: "helper", is_owner: false }, { display_name: "szymon", avatar: "https://x.test/a.png", is_owner: true } ] },
      devlogs: [
        { id: 9, title: "Printed", content: "It works.\n\n![p](https://cdn.hackclub.com/a/p.png)", time_hours: 1.5, lapse_urls: [ "https://lapse.test/1" ], created_at: "September 24, 2026" },
        { id: 8, title: "", content: "Designed it.", time_hours: 0.1, lapse_urls: [], created_at: "September 24, 2026" }
      ]
    }
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/projects/710") { [ 200, {}, page(props) ] }

    snapshot = with_forge(stubs) { Forge.project("710") }
    assert_equal [ "Ender press", "A press", "approved", true, 96 ], snapshot.values_at("title", "description", "status", "hardware", "minutes")
    assert_equal "szymon", snapshot.dig("owner", "name")
    assert_equal [ [ "8", "2026-09-24", 6, "Designed it." ], [ "9", "2026-09-24", 90, "**Printed**\n\nIt works.\n\n![p](https://cdn.hackclub.com/a/p.png)\n\nTimelapse: https://lapse.test/1" ] ],
                 snapshot["entries"].map { it.values_at("ref", "at", "minutes", "body") }
  end

  test "an unlisted project is an error" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/projects/1") { [ 302, { "Location" => "https://forge.hackclub.com/" }, "" ] }

    assert_raises(Forge::Error) { with_forge(stubs) { Forge.project("1") } }
  end

  private

  def page(props) = %(<script data-page="app" type="application/json">#{ERB::Util.html_escape({ component: "Projects/Show", props: props }.to_json)}</script>)
  def with_forge(stubs, &) = stub_method(Forge, :connection, Faraday.new { it.adapter :test, stubs }, &)
end
