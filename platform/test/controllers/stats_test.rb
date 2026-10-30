require "test_helper"

class StatsTest < ActionDispatch::IntegrationTest
  test "anyone can see the stats" do
    assert_equal "7d", inertia_props(stats_path(range: "7d"), "Stats/Show")["range"]

    props = load_deferred(stats_path(range: "7d"), "Stats/Show", "active", "daily", "funnel", "sources", "writing")
    assert_equal 7, props["daily"]["days"].size
    assert_equal ProgramStats::FUNNEL.size, props["funnel"].size
  end
end
