require "test_helper"

# Every page has a query budget. A page that grows past it is loading more on each change until it is slow;
# fix the page (preload, grouped aggregate, defer, paginate) rather than raising the number. Fixtures are small,
# so these counts must not depend on how many records exist: an N+1 shows up as a count that grows with data.
class QueryBudgetTest < ActionDispatch::IntegrationTest
  test "guest pages" do
    assert_query_budget(2) { get root_path }
    assert_query_budget(1) { get dev_path }
  end

  test "member pages" do
    sign_in_as users(:member)

    assert_query_budget(4) { get home_path }
    assert_query_budget(8) { load_deferred(home_path, "Home/Index", "projects", "stats", "activity") }
    assert_query_budget(5) { load_deferred(home_path, "Home/Index", "xp") }
    assert_query_budget(6) { get projects_path }
    assert_query_budget(10) { get project_path(projects(:station)) }
    assert_query_budget(2) { get new_project_path }
    assert_query_budget(3) { get edit_project_path(projects(:station)) }
  end

  test "onboarding pages" do
    sign_in_as users(:newcomer)
    assert_query_budget(5) { get home_path }
  end

  test "banned page" do
    sign_in_as users(:banned)
    assert_query_budget(2) { get sorry_path }
  end

  test "admin pages" do
    sign_in_as users(:admin)

    assert_query_budget(3) { get admin_root_path }
    assert_query_budget(12) { load_deferred(admin_root_path, "Admin/Dashboard/Index", "stats", "activity", "admin_stats") }

    assert_query_budget(3) { get admin_users_path }
    assert_query_budget(8) { load_deferred(admin_users_path, "Admin/Users/Index", "users", "pagy", "total_count") }
    assert_query_budget(6) { get admin_user_path(users(:member)) }

    assert_query_budget(3) { get admin_projects_path }
    assert_query_budget(8) { load_deferred(admin_projects_path, "Admin/Projects/Index", "projects", "pagy", "total_count") }
    assert_query_budget(9) { get admin_project_path(projects(:station)) }
  end
end
