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

    # A team on the project, so the budgets cover loading teammates.
    projects(:station).memberships.create!(user: users(:admin))
    users(:admin).project_invites.create!(project: projects(:unlinked), inviter: users(:member))

    # Nothing deferred (HomeController#index): the whole page in one round trip. Projects bring their members, and
    # the invites waiting for the person come in one more.
    assert_query_budget(15) { get home_path }
    assert_query_budget(8) { get projects_path }
    # 11 since journals can have several Lapse timelapses: one preload query, whatever the page holds. The team
    # costs what the owner query it replaced did: members, what each logged here and invites waiting, with journal
    # authors taken from the team.
    assert_query_budget(11) { get project_path(projects(:station)) }
    assert_query_budget(4) { load_deferred(project_path(projects(:station)), "Projects/Show", "lapse") }
    assert_query_budget(2) { get new_project_path }
    # Plus the team's members, which the project's serializer carries.
    assert_query_budget(4) { get edit_project_path(projects(:station)) }
    assert_query_budget(2) { get docs_path }
    assert_query_budget(2) { get shop_path }
    assert_query_budget(2) { get transfers_path }
    # The pet switch: how many journals and the first one's day, in one query.
    assert_query_budget(3) { get settings_path }
    # Not a page: what the pet's timer asks for after every visit and every 30 seconds. The last journal, then
    # huddle sessions, pauses and timer sessions since it, plus the live huddle when one is configured.
    assert_query_budget(4) { get timer_path }
  end

  test "team pages" do
    invite = users(:newcomer).project_invites.create!(project: projects(:station), inviter: users(:member))
    sign_in_as users(:admin)
    assert_query_budget(8) { get join_path(projects(:station).join_token) }

    sign_in_as users(:newcomer)
    assert_query_budget(9) { get invite_path(invite) }
  end

  test "onboarding pages" do
    sign_in_as users(:newcomer)
    # Plus any team invites waiting for them.
    assert_query_budget(8) { get home_path }
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
    assert_query_budget(8) { load_deferred(admin_user_path(users(:member)), "Admin/Users/Show", "streak") }

    assert_query_budget(3) { get admin_projects_path }
    assert_query_budget(8) { load_deferred(admin_projects_path, "Admin/Projects/Index", "projects", "pagy", "total_count") }
    # Plus the team's members.
    assert_query_budget(10) { get admin_project_path(projects(:station)) }
    assert_query_budget(3) { get admin_transfers_path }
    assert_query_budget(8) { load_deferred(admin_transfers_path, "Admin/Transfers/Index", "transfers", "pagy", "counts") }
    assert_query_budget(6) { get admin_transfer_path(project_transfers(:stardance)) }
    assert_query_budget(3) { get admin_streaks_path }
    assert_query_budget(9) { load_deferred(admin_streaks_path, "Admin/Streaks/Index", "rows", "pagy", "weeks", "counts") }
    assert_query_budget(8) { load_deferred(admin_streaks_path(tab: "log"), "Admin/Streaks/Index", "rows", "pagy") }

    assert_query_budget(3) { get admin_insights_path }
    # One aggregate per panel, whatever the number of requests recorded.
    assert_query_budget(6) { load_deferred(admin_insights_path, "Admin/Insights/Show", "summary", "series", "breakdown", "slowest", "statuses") }
    assert_query_budget(3) { get admin_stats_path }
    # Recent journals and the huddle, pauses and timer sessions for active builders; the days from signups, visits, journals and the huddle, pauses and timer sessions;
    # the funnel in one; the AI-writing checks in one.
    assert_query_budget(13) { load_deferred(admin_stats_path, "Admin/Stats/Show", "active", "daily", "funnel", "writing") }
    assert_query_budget(4) { get admin_teams_path }
    # The race's first XP, every week's XP by team, which were paid and the chart's running totals; then the week's
    # teams, chart, leaders and projects.
    assert_query_budget(11) { load_deferred(admin_teams_path, "Admin/Teams/Show", "history", "overall_timeline", "teams", "timeline", "leaders", "projects") }
    assert_query_budget(3) { get admin_jobs_path }
    # A count per status tab, the queue names, then the page of jobs with the execution its status shows.
    assert_query_budget(11) { load_deferred(admin_jobs_path, "Admin/Jobs/Index", "jobs", "pagy", "counts", "queue_names") }
    assert_query_budget(4) { load_deferred(admin_jobs_path(status: "queues"), "Admin/Jobs/Index", "queues") }
    assert_query_budget(3) { get admin_flags_path }

    AdminToken.mint(user: users(:admin), name: "admin@laptop")
    assert_query_budget(4) { get admin_mcp_path }
    assert_query_budget(6) { load_deferred(admin_mcp_path, "Admin/Mcp/Index", "actions", "sql_changes") }
    change = McpSqlChange.request!(sql: "UPDATE projects SET title = 'x' WHERE id = #{projects(:station).id}", admin: users(:admin), token: AdminToken.last)
    assert_query_budget(5) { get admin_sql_change_path(change) }
  end
end
