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

  test "landing offers a dev sign in dropdown outside production" do
    get root_path
    assert_includes response.body, users(:member).email
    assert_includes response.body, dev_sign_in_as_path(users(:member).public_id)
    assert_not_includes response.body, users(:member).hca_id
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
    props = inertia_props(home_path, "Home/Index")
    assert props["slack"]["connected"]
    assert_nil props["stats"]

    props = load_deferred(home_path, "Home/Index", "projects", "stats", "activity")
    assert_equal [ projects(:station), projects(:unlinked) ].map(&:public_id).sort, props["projects"].pluck("id").sort
    assert_equal({ "minutes" => 150, "journals" => 3, "missing_hours" => 1 }, props["stats"].except("last_journal_at"))
    assert_equal HomeController::ACTIVITY_DAYS, props["activity"].size
    assert_equal Time.current.in_time_zone(users(:member).timezone).to_date.iso8601, props["activity"].last["date"]
    assert_equal 150, props["activity"].last["minutes"]
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
