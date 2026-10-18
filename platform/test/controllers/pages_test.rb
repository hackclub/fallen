require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  test "landing renders for guests" do
    get root_path
    assert_response :success
    assert_includes response.body, "Landing/Index"
  end

  test "landing renders for signed in users" do
    sign_in_as users(:member)
    get root_path
    assert_response :success
    assert_includes response.body, "Landing/Index"
  end

  test "docs and settings require sign in" do
    get docs_path
    assert_redirected_to root_path
    get settings_path
    assert_redirected_to root_path
  end

  test "settings shows the Slack connection" do
    sign_in_as users(:member)
    inertia_props(docs_path, "Docs/Show")
    props = inertia_props(settings_path, "Settings/Show")
    assert_equal users(:member).slack_connected?, props["slack"]["connected"]
  end

  test "settings shows the Lapse connection" do
    sign_in_as users(:member)
    with_env("LAPSE_CLIENT_ID" => "svc_test", "LAPSE_CLIENT_SECRET" => "scs_test") do
      assert_equal({ "configured" => true, "connected" => false, "synced_at" => nil }, inertia_props(settings_path, "Settings/Show")["lapse"])
      users(:member).update!(lapse_token: "lapse-token")
      assert inertia_props(settings_path, "Settings/Show")["lapse"]["connected"]
    end
  end

  test "home requires sign in" do
    get home_path
    assert_redirected_to root_path
  end

  test "home renders for signed in users and admin is hidden for members" do
    sign_in_as users(:member)
    get home_path
    assert_response :success
    assert_includes response.body, "Home/Index"
    get admin_root_path
    assert_response :not_found
  end

  test "home streams in my projects, totals and daily activity" do
    sign_in_as users(:member)
    assert_nil inertia_props(home_path, "Home/Index")["stats"]

    props = load_deferred(home_path, "Home/Index", "projects", "stats", "activity")
    assert_equal [ projects(:station), projects(:unlinked) ].map(&:public_id).sort, props["projects"].pluck("id").sort
    assert_equal({ "minutes" => 150, "journals" => 3, "missing_hours" => 1 }, props["stats"].except("last_journal_at"))
    assert_equal HomeController::ACTIVITY_DAYS, props["activity"].size
    assert_equal Time.current.in_time_zone(users(:member).timezone).to_date.iso8601, props["activity"].last["date"]
    assert_equal 150, props["activity"].last["minutes"]
  end

  test "home streams in where I stand" do
    sign_in_as users(:member)
    xp = load_deferred(home_path, "Home/Index", "xp")["xp"]
    assert_equal 20, xp["total"]
    assert_equal 1, xp["form"]
    assert_equal 200, xp["next_stage_xp"]
    assert_equal "lulu", xp["team"]
    assert_equal 1.0, xp["multiplier"]
    assert_equal 3, xp["freezes"]
    assert_equal [ Date.current.iso8601 ], xp["week"]["days"]
    assert_equal({ "lulu" => 20 }, xp["week"]["totals"])
  end

  test "banned users are sent to /sorry" do
    sign_in_as users(:banned)
    get home_path
    assert_redirected_to sorry_path
  end

  test "admins reach the admin dashboard and can update users" do
    sign_in_as users(:admin)
    get admin_root_path
    assert_response :success
    patch admin_user_path(users(:member)), params: { user: { roles: [ "user", "reviewer" ], is_banned: false } }
    assert_redirected_to admin_user_path(users(:member))
    assert users(:member).reload.reviewer?
  end
end
