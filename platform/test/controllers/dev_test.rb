require "test_helper"

class DevTest < ActionDispatch::IntegrationTest
  test "lists accounts to sign in as, without their HCA ids" do
    props = inertia_props(dev_path, "Dev/Index")
    assert_includes props["users"].pluck("id"), users(:member).public_id
    assert_not_includes response.body, users(:member).hca_id
  end

  test "a trial account can still reach the account switcher" do
    post trial_session_path, params: { email: "trial@example.com" }
    inertia_props(dev_path, "Dev/Index")
    get dev_sign_in_as_path(users(:member).public_id)
    assert_redirected_to home_path
  end

  test "searches accounts" do
    props = inertia_props(dev_path(q: users(:admin).display_name), "Dev/Index")
    assert_includes props["users"].pluck("id"), users(:admin).public_id
    assert_not_includes props["users"].pluck("id"), users(:member).public_id
  end

  test "signs in as an existing account by public id or email" do
    get dev_sign_in_as_path(users(:member).public_id)
    assert_redirected_to home_path
    get dev_sign_in_as_path(users(:admin).email)
    assert_redirected_to home_path
    assert_equal users(:admin).display_name, inertia_props(home_path, "Home/Index")["auth"]["user"]["display_name"]
  end

  test "creates a fresh account and signs in as it" do
    assert_difference -> { User.count } do
      post dev_users_path, params: { roles: %w[user reviewer bogus], display_name: "Ada", pet: "lulu", is_adult: "true" }
    end
    assert_redirected_to home_path
    user = User.last
    assert_equal %w[user reviewer], user.roles
    assert_equal "lulu", user.pet
    assert user.is_adult
    assert_match(/\Aada\.\h+@example\.com\z/, user.email)
    assert_equal "Ada", inertia_props(home_path, "Home/Index")["auth"]["user"]["display_name"]
  end

  test "creates a default account from a bookmarkable URL" do
    get dev_sign_in_as_new_path
    assert_redirected_to home_path
    assert_equal %w[user], User.last.roles
    assert_nil User.last.pet
  end

  test "an invalid account goes back with the reason" do
    assert_no_difference -> { User.count } do
      post dev_users_path, params: { pet: "dragon" }
    end
    assert_redirected_to dev_path
    assert_match(/Pet/, flash[:alert])
  end
  test "skip slack marks the account connected with a token that is not real" do
    sign_in_as users(:newcomer)
    post dev_skip_slack_path
    assert_redirected_to home_path
    assert users(:newcomer).reload.slack_connected?
  end
end
