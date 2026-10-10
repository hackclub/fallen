require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  test "landing renders for guests" do
    get root_path
    assert_response :success
    assert_includes response.body, "Landing/Index"
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

  test "banned users are sent to /sorry" do
    sign_in_as users(:banned)
    get home_path
    assert_redirected_to sorry_path
  end

  test "admins reach the admin dashboard and can update users" do
    sign_in_as users(:admin)
    get admin_root_path
    assert_response :success
    get admin_users_path(query: "member")
    assert_response :success
    assert_includes response.body, users(:member).public_id
    assert_not_includes response.body, users(:member).hca_id, "index rows do not leak detail fields"

    patch admin_user_path(users(:member)), params: { user: { roles: [ "user", "reviewer" ], is_banned: false } }
    assert_redirected_to admin_user_path(users(:member))
    assert users(:member).reload.reviewer?
  end
end
