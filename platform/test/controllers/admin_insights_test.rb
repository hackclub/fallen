require "test_helper"

class AdminInsightsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
    now = Time.current
    [ [ "HomeController", "index", 40.0, 200 ], [ "HomeController", "index", 60.0, 200 ], [ "ProjectsController", "show", 900.0, 500 ] ]
      .each_with_index do |(controller, action, duration, status), i|
        ActiveInsights::Request.create!(controller:, action:, duration:, status:, http_method: "GET", path: "/p/#{i}",
          format: "html", db_runtime: duration / 4, view_runtime: duration / 4, started_at: now - (i + 1).minutes,
          finished_at: now - (i + 1).minutes + (duration / 1000.0))
      end
    ActiveInsights::Job.create!(job: "CloseWeekJob", queue: "background", duration: 1200.0, queue_time: 300.0,
      db_runtime: 100.0, started_at: now - 5.minutes, finished_at: now - 5.minutes + 1.2)
    # Older than the longest range, so never counted.
    ActiveInsights::Request.create!(controller: "HomeController", action: "index", duration: 5.0, status: 200,
      started_at: 40.days.ago, finished_at: 40.days.ago)
  end

  test "the shell renders before any timing is read" do
    props = inertia_props(admin_insights_path, "Admin/Insights/Show")
    assert_equal [ "requests", "24h" ], props.values_at("kind", "range")
    assert_not props.key?("summary"), "panels are deferred"
  end

  test "requests: totals, errors and the endpoints that cost the most time first" do
    props = load_deferred(admin_insights_path, "Admin/Insights/Show", "summary", "series", "breakdown", "slowest", "statuses")

    assert_equal 3, props["summary"]["count"]
    assert_equal 1, props["summary"]["errors"]
    assert_equal 96, props["series"].size, "a point every 15 minutes for 24 hours"
    assert_equal 3, props["series"].sum { it["count"] }
    assert_equal [ "ProjectsController#show", "HomeController#index" ], props["breakdown"].pluck("name")
    assert_equal [ 1, 2 ], props["breakdown"].pluck("count")
    assert_equal [ 900.0, 60.0, 40.0 ], props["slowest"].pluck("duration")
    assert_equal({ "2xx" => 2, "5xx" => 1 }, props["statuses"].to_h { [ it["status"], it["count"] ] })
  end

  test "one endpoint narrows every panel to it" do
    path = admin_insights_path(name: "HomeController#index", range: "1h")
    props = load_deferred(path, "Admin/Insights/Show", "summary", "series", "breakdown", "slowest")

    assert_equal 2, props["summary"]["count"]
    assert_equal 50.0, props["summary"]["p50"]
    assert_equal 60, props["series"].size
    assert_empty props["breakdown"]
    assert_equal [ "/p/1", "/p/0" ], props["slowest"].pluck("path")
  end

  test "jobs show run time and how long they waited" do
    props = load_deferred(admin_insights_path(kind: "jobs", range: "7d"), "Admin/Insights/Show", "summary", "breakdown")
    assert_equal 1, props["summary"]["count"]
    assert_equal 300.0, props["summary"]["queue_p95"]
    assert_equal [ { "name" => "CloseWeekJob", "queue" => "background", "count" => 1 } ],
      props["breakdown"].map { it.slice("name", "queue", "count") }
  end

  test "an unknown range falls back to the default" do
    assert_equal "24h", inertia_props(admin_insights_path(range: "1y"), "Admin/Insights/Show")["range"]
  end
end
