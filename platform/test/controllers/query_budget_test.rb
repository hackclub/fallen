require "test_helper"

# Every page has a query budget. A page that grows past it is loading more on each change until it is slow;
# fix the page (preload, grouped aggregate, defer, paginate) rather than raising the number. Fixtures are small,
# so these counts must not depend on how many records exist: an N+1 shows up as a count that grows with data.
class QueryBudgetTest < ActionDispatch::IntegrationTest
  test "guest pages" do
    assert_query_budget(2) { get root_path }
    assert_query_budget(1) { get dev_path }
    assert_query_budget(0) { get workshop_rsvp_path }
    # The same panels as /admin/stats, uncached here (the test cache is a null store).
    assert_query_budget(14) { load_deferred(stats_path, "Stats/Show", "active", "daily", "funnel", "sources", "writing") }
  end

  test "member pages" do
    sign_in_as users(:member)

    # A team on the project, so the budgets cover loading teammates.
    projects(:station).memberships.create!(user: users(:admin))
    users(:admin).project_invites.create!(project: projects(:unlinked), inviter: users(:member))

    # Nothing deferred (HomeController#index): the whole page in one round trip. Projects bring their members, and
    # the invites waiting for the person come in one more. Two for the XP bar's last seven days and the Slack ping box.
    assert_query_budget(17) { get home_path }
    assert_query_budget(8) { get projects_path }
    # 11 since journals can have several Lapse timelapses: one preload query, whatever the page holds. The team
    # costs what the owner query it replaced did: members, what each logged here and invites waiting, with journal
    # authors taken from the team. One more for the latest design submission.
    assert_query_budget(12) { get project_path(projects(:station)) }
    assert_query_budget(4) { load_deferred(project_path(projects(:station)), "Projects/Show", "lapse") }
    # Someone else's project: the same, less the design submission, which stays with its team.
    assert_query_budget(9) { get project_path(projects(:admins)) }
    # Journal review on the project page: reviews, to-dos, held XP and whether the team can ask for one.
    assert_query_budget(6) { load_deferred(project_path(projects(:station)), "Projects/Show", "journal_review") }
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

  test "design review pages" do
    submission = submit_design(projects(:station))
    submit_design(projects(:unlinked)).update!(status: "returned")
    reviewer = users(:newcomer)
    reviewer.update!(roles: %w[user design_reviewer])
    sign_in_as reviewer

    assert_query_budget(3) { get review_submissions_path }
    assert_query_budget(14) { load_deferred(review_submissions_path, "Review/Submissions/Index", "submissions", "pagy", "counts") }
    # Claims it, then everything the review needs, the same count whatever the number of journals or parts.
    assert_query_budget(30) { get review_submission_path(submission) }
    # A file for the repo viewer: the session, the submission and its snapshot, then finding or making the file.
    # Polling a done one reads its attachment and blob instead of writing.
    assert_query_budget(6) { post review_submission_repo_files_path(submission), params: { path: "board.kicad_pcb" }, as: :json }
    RepoFile.last.store("(kicad_pcb)")
    assert_query_budget(6) { post review_submission_repo_files_path(submission), params: { path: "board.kicad_pcb" }, as: :json }

    # The project page with a submission on it: that, its parts, its payout and its screenshots, the same five queries
    # whatever their number, on top of a fresh sign-in's two.
    sign_in_as users(:member)
    assert_query_budget(19) { get project_path(projects(:station)) }
  end

  test "journal review pages" do
    project = projects(:station)
    project.journals.kept.update_all(duration_minutes: ProgressStatus::FIRST_AT_MINUTES)
    ProgressStatus.refresh(project)
    reviewer = users(:newcomer)
    reviewer.update!(roles: %w[user reviewer])
    sign_in_as reviewer

    assert_query_budget(3) { get journal_review_root_path }
    assert_query_budget(10) { load_deferred(journal_review_root_path, "Review/Progress/Index", "projects", "pagy", "counts") }
    # Claims it, then everything the review needs, the same count whatever the number of journals.
    assert_query_budget(20) { get journal_review_project_path(project) }
    project.progress_status.update!(starred_at: Time.current, starred_by: reviewer)
    assert_query_budget(8) { load_deferred(starred_projects_path, "Review/MarkedProjects/Index", "projects", "pagy") }
    ProgressReview.decide(project.progress_status, reviewer:, verdict: "check_back", feedback: "More photos")
    assert_query_budget(6) { load_deferred(journal_review_projects_path(tab: "decided"), "Review/Progress/Index", "reviews", "pagy") }
  end

  test "admin pages" do
    sign_in_as users(:admin)

    assert_query_budget(3) { get admin_root_path }
    assert_query_budget(12) { load_deferred(admin_root_path, "Admin/Dashboard/Index", "stats", "activity", "admin_stats") }

    assert_query_budget(3) { get admin_users_path }
    assert_query_budget(8) { load_deferred(admin_users_path, "Admin/Users/Index", "users", "pagy", "total_count") }
    assert_query_budget(6) { get admin_user_path(users(:member)) }
    # The streak calendar, then the latest timezone changes.
    assert_query_budget(9) { load_deferred(admin_user_path(users(:member)), "Admin/Users/Show", "streak", "timezone_changes") }

    assert_query_budget(3) { get admin_projects_path }
    assert_query_budget(8) { load_deferred(admin_projects_path, "Admin/Projects/Index", "projects", "pagy", "total_count") }
    # Plus the team's members.
    assert_query_budget(10) { get admin_project_path(projects(:station)) }
    assert_query_budget(3) { get admin_transfers_path }
    assert_query_budget(8) { load_deferred(admin_transfers_path, "Admin/Transfers/Index", "transfers", "pagy", "counts") }
    # Plus whoever reached out, once anyone has.
    project_transfers(:stardance).update_columns(reached_out_by_id: users(:admin).id, reached_out_at: Time.current)
    assert_query_budget(9) { load_deferred(admin_transfers_path, "Admin/Transfers/Index", "transfers", "pagy", "counts") }
    assert_query_budget(6) { get admin_transfer_path(project_transfers(:stardance)) }
    assert_query_budget(5) { get admin_grants_path }
    assert_query_budget(8) { load_deferred(admin_grants_path, "Admin/Grants/Index", "payouts", "pagy", "totals") }
    assert_query_budget(3) { get admin_streaks_path }
    assert_query_budget(3) { get admin_workshop_rsvps_path }
    assert_query_budget(5) { load_deferred(admin_workshop_rsvps_path, "Admin/WorkshopRsvps/Index", "rsvps", "pagy", "counts") }
    assert_query_budget(9) { load_deferred(admin_streaks_path, "Admin/Streaks/Index", "rows", "pagy", "weeks", "counts") }
    assert_query_budget(8) { load_deferred(admin_streaks_path(tab: "log"), "Admin/Streaks/Index", "rows", "pagy") }

    assert_query_budget(3) { get admin_insights_path }
    # One aggregate per panel, whatever the number of requests recorded.
    assert_query_budget(6) { load_deferred(admin_insights_path, "Admin/Insights/Show", "summary", "series", "breakdown", "slowest", "statuses") }
    assert_query_budget(3) { get admin_stats_path }
    # Recent journals and the huddle, pauses and timer sessions for active builders; the days from signups, visits, journals and the huddle, pauses and timer sessions;
    # the funnel in one; the sources in one; the AI-writing checks in one.
    assert_query_budget(14) { load_deferred(admin_stats_path, "Admin/Stats/Show", "active", "daily", "funnel", "sources", "writing") }
    assert_query_budget(3) { get admin_qualifying_path }
    # Everyone's statuses and the extra tabs' counts in two, the history from everyone's first approval and XP by day,
    # the spread and the hours funnel in one each.
    assert_query_budget(6) { load_deferred(admin_qualifying_path, "Admin/Qualifying/Show", "summary", "history", "spread", "hours_funnel") }
    assert_query_budget(8) { load_deferred(admin_qualifying_path, "Admin/Qualifying/Show", "rows", "pagy") }
    # Who is locking in, the top of them, and their journals.
    assert_query_budget(3) { load_deferred(admin_qualifying_path, "Admin/Qualifying/Show", "locking_in") }
    assert_query_budget(4) { get admin_teams_path }
    # Every week's XP by team, which were paid and the chart's running totals; then the week's teams, chart, leaders
    # (with their hours, pet changes and days with XP) and projects.
    assert_query_budget(13) { load_deferred(admin_teams_path, "Admin/Teams/Show", "history", "overall_timeline", "teams", "timeline", "leaders", "projects") }
    # Every week by the hour, when "All weeks" by weekday is open.
    assert_query_budget(1) { load_deferred(admin_teams_path, "Admin/Teams/Show", "weekdays") }
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

    # Plus where else its recordings were counted: Fallen journals in one, other transfers in one.
    project_transfers(:stardance).update_column(:lapse_recordings, [ { "key" => "lapse:A", "seconds" => 60 } ])
    assert_query_budget(5) { get admin_transfer_lapse_path(project_transfers(:stardance)) }
  end
end
