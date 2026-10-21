require "test_helper"

class AdminStatsTest < ActionDispatch::IntegrationTest
  test "the shell renders before any stat is read" do
    sign_in_as users(:admin)
    props = inertia_props(admin_stats_path, "Admin/Stats/Show")

    assert_equal "30d", props["range"]
    assert_not props.key?("daily"), "panels are deferred"
  end

  test "every panel loads" do
    sign_in_as users(:admin)
    props = load_deferred(admin_stats_path(range: "all"), "Admin/Stats/Show", "active", "daily", "funnel")

    assert_equal ProgramStats::FUNNEL.size, props["funnel"].size
    assert props["daily"]["days"].any?
  end

  test "members are turned away" do
    sign_in_as users(:member)
    get admin_stats_path
    assert_response :not_found
  end
end
