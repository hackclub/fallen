require "test_helper"

class AdminStatsTest < ActionDispatch::IntegrationTest
  test "the shell renders before any stat is read" do
    sign_in_as users(:admin)
    props = inertia_props(admin_stats_path, "Admin/Stats/Show")

    assert_equal "30d", props["range"]
    assert_not props.key?("daily"), "panels are deferred"
    assert_equal [ "default" ], response.parsed_body["deferredProps"].keys, "the panels and sidebar load in one request"
  end

  test "every panel loads" do
    sign_in_as users(:admin)
    props = load_deferred(admin_stats_path(range: "all"), "Admin/Stats/Show", "active", "daily", "funnel")

    assert_equal "qualified", props["funnel"].last["key"], "with the checkpoints to qualifying"
    assert props["daily"]["days"].any?
  end

  test "picks a custom range by its first and last day" do
    sign_in_as users(:admin)
    path = admin_stats_path(from: "2026-01-01", to: "2026-01-07")
    assert_equal [ "custom", "2026-01-01", "2026-01-07" ], inertia_props(path, "Admin/Stats/Show").values_at("range", "from", "to")
    assert_equal 7, load_deferred(path, "Admin/Stats/Show", "daily")["daily"]["days"].size
  end

  test "members are turned away" do
    sign_in_as users(:member)
    get admin_stats_path
    assert_response :not_found
  end
end
