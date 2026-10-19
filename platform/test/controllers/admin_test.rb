require "test_helper"

class AdminTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "user list rows arrive in the deferred request and leave out detail fields" do
    get admin_users_path(query: "member")
    assert_response :success
    assert_not_includes response.body, users(:member).public_id, "rows are deferred"

    users = load_deferred(admin_users_path(query: "member"), "Admin/Users/Index", "users", "pagy", "total_count")
    assert_includes users["users"].pluck("id"), users(:member).public_id
    assert_not users["users"].first.key?("hca_id"), "index rows do not leak detail fields"
    assert_equal 1, users["pagy"]["page"]
  end

  test "user list marks trial accounts and where a soft signup came from" do
    trial = User.create!(email: "fallout@example.com", display_name: "fallout", roles: [ "user" ], soft_signup: "fallout_link")
    rows = load_deferred(admin_users_path, "Admin/Users/Index", "users")["users"].index_by { it["id"] }

    assert_equal [ true, "fallout_link" ], rows[trial.public_id].values_at("is_trial", "soft_signup")
    assert_equal [ false, nil ], rows[users(:member).public_id].values_at("is_trial", "soft_signup")
  end

  test "deleted users are hidden unless asked for" do
    users(:member).discard
    rows = load_deferred(admin_users_path, "Admin/Users/Index", "users")["users"].pluck("id")
    assert_not_includes rows, users(:member).public_id

    rows = load_deferred(admin_users_path(include_deleted: "1"), "Admin/Users/Index", "users")["users"].pluck("id")
    assert_includes rows, users(:member).public_id
  end

  test "projects list every owner's projects with totals" do
    props = load_deferred(admin_projects_path(query: "weather"), "Admin/Projects/Index", "projects", "total_count")
    assert_equal [ projects(:station).public_id ], props["projects"].pluck("id")
    assert_equal users(:member).public_id, props["projects"].first.dig("user", "id")
    assert_equal projects(:station).total_minutes, props["projects"].first["total_minutes"]
    assert_equal 1, props["total_count"]
  end

  test "project and user pages render" do
    get admin_project_path(projects(:station))
    assert_response :success
    assert_includes response.body, journals(:first).body

    get admin_user_path(users(:member))
    assert_response :success
    assert_includes response.body, projects(:station).public_id
  end

  test "dashboard defers the stats, the activity chart and the sidebar counts" do
    get admin_root_path
    assert_response :success
    assert_not_includes response.body, "minutes_logged", "stats are deferred"

    props = load_deferred(admin_root_path, "Admin/Dashboard/Index", "stats", "activity", "admin_stats")
    assert_equal Journal.kept.needing_hours.count, props["stats"]["journals_missing_hours"]
    assert_equal Admin::DashboardController::CHART_DAYS, props["activity"].size
    assert_equal User.kept.count, props["admin_stats"]["users_count"]
  end

  test "project page paginates journals and counts missing hours in full" do
    pad_journals(projects(:station), Pagy::OPTIONS[:limit])
    props = inertia_props(admin_project_path(projects(:station), page: 2), "Admin/Projects/Show")
    assert_equal 2, props["pagy"]["page"]
    assert_equal 2, props["journals"].size
    assert_equal Pagy::OPTIONS[:limit] + 1, props["missing_hours"]
  end

  test "admins approve a finished project and can take it back" do
    sign_in_as users(:admin)
    patch admin_project_path(projects(:station)), params: { project: { approved: true } }
    assert_redirected_to admin_project_path(projects(:station))
    assert projects(:station).reload.approved?
    assert_equal true, inertia_props(admin_project_path(projects(:station)), "Admin/Projects/Show")["can"]["update"]

    patch admin_project_path(projects(:station)), params: { project: { approved: false } }
    assert_not projects(:station).reload.approved?
  end

  test "members get a 404 on admin projects" do
    sign_in_as users(:member)
    get admin_projects_path
    assert_response :not_found
  end

  test "insights render for admins" do
    get "/admin/insights"
    assert_response :success
  end

  test "members get a 404 on insights" do
    sign_in_as users(:member)
    get "/admin/insights"
    assert_response :not_found
  end
end
