require "test_helper"

class ImpersonationTest < ActionDispatch::IntegrationTest
  test "admins can browse as a member and stop again" do
    sign_in_as users(:admin)
    post impersonate_admin_user_path(users(:member))
    assert_redirected_to home_path

    get home_path
    assert_response :success
    assert_includes response.body, users(:member).display_name
    assert_includes response.body, "impersonator_name"

    get admin_root_path
    assert_response :not_found, "the impersonated member has no admin access"

    delete impersonation_path
    assert_redirected_to admin_user_path(users(:member))
    get admin_root_path
    assert_response :success
  end

  test "staff and banned users cannot be impersonated" do
    sign_in_as users(:admin)
    post impersonate_admin_user_path(users(:banned)), headers: { "Referer" => admin_user_path(users(:banned)) }
    assert_redirected_to admin_user_path(users(:banned))
    assert_match(/not allowed/, flash[:alert])
    assert_nil session[:impersonator_id]
    assert_not UserPolicy.new(users(:admin), users(:admin)).impersonate?
  end

  test "members cannot impersonate" do
    sign_in_as users(:member)
    post impersonate_admin_user_path(users(:admin))
    assert_response :not_found
  end
end
