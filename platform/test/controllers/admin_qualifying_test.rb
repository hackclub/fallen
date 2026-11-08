require "test_helper"

class AdminQualifyingTest < ActionDispatch::IntegrationTest
  setup { travel_to Time.utc(2026, 11, 10, 17) }

  test "the charts and the table are deferred, and a tab lists the people in it" do
    sign_in_as users(:admin)
    users(:member).update_columns(xp: 1)
    props = inertia_props(admin_qualifying_path(tab: "off_track"), "Admin/Qualifying/Show")

    assert_not props.key?("rows"), "the table is deferred"
    assert_not props.key?("history"), "the charts are deferred"

    props = load_deferred(admin_qualifying_path(tab: "off_track"), "Admin/Qualifying/Show", "rows", "pagy", "summary", "history", "spread", "hours_funnel", "locking_in")
    assert_equal [ "Member Person" ], props["rows"].map { it["display_name"] }
    assert_equal QualifyingPace.on_track_xp("lulu", Date.new(2026, 11, 9)), props["rows"].first["line_xp"]
    assert_equal 1, props["summary"]["statuses"]["off_track"]["all"]
    assert_equal "2026-11-09", props["history"]["all"]["days"].last["date"], "up to the end of yesterday"
    assert_equal User.on_a_team.count, props["spread"]["all"].sum { it["count"] }
    assert props["rows"].first.key?("last_journal_at")
    assert_kind_of Integer, props["locking_in"]["count"]
    assert_kind_of Integer, props["rows"].first["projected_xp"]
    assert_equal "team", props["hours_funnel"].first["key"]
  end

  test "members are turned away" do
    sign_in_as users(:member)
    get admin_qualifying_path
    assert_response :not_found
  end
end
