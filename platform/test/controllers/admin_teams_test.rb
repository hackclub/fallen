require "test_helper"

class AdminTeamsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "the week shell renders before the race is read" do
    sign_in_as users(:admin)
    props = inertia_props(admin_teams_path, "Admin/Teams/Show")

    assert_equal Week.of(Date.current).start.iso8601, props["week"]["start"]
    assert_equal [ Week.of(Date.current).start.iso8601 ], props["weeks"].map { it["start"] }, "week 1 is the first journal's"
    assert_not props["can"]["pay"], "this week is still running"
    assert_not props.key?("leaders"), "the race is deferred"
  end

  test "the race loads, never for a week after this one" do
    sign_in_as users(:admin)
    props = load_deferred(admin_teams_path(week: (Date.current + 30).iso8601), "Admin/Teams/Show", "history", "overall_timeline", "teams", "timeline", "leaders", "projects")

    assert_equal [ { "start" => Week.of(Date.current).start.iso8601, "xp" => { "lulu" => 20, "sami" => 0 },
                     "transferred" => { "lulu" => 0, "sami" => 0 }, "paid" => false } ], props["history"]
    assert_equal({ "lulu" => 0, "sami" => 0 }, props["timeline"].first.slice("lulu", "sami"))
    assert_equal({ "lulu" => 20, "sami" => 0 }, props["timeline"].last.slice("lulu", "sami"), "running totals up to now")
    assert_equal props["timeline"].last.slice("lulu", "sami"), props["overall_timeline"].last.slice("lulu", "sami")
    assert_equal 20, props["teams"].find { it["pet"] == "lulu" }["xp"]
    assert_equal [ users(:member).public_id ], props["leaders"].map { it["user"]["id"] }
    assert_equal [ [ projects(:station).public_id, 12, 90 ], [ projects(:unlinked).public_id, 8, 60 ] ],
      props["projects"].map { it.values_at("id", "xp", "minutes") }
  end

  test "transfers stay out of the race, and count on the people, projects and charts when asked for" do
    sign_in_as users(:admin)
    transfer = project_transfers(:stardance)
    transfer.update!(status: "approved", project: projects(:station), approved_minutes: 120, xp: 30)
    users(:member).xp_entries.create!(kind: "transfer", amount: 30, day: Date.current, source: transfer)
    deferred = %w[history overall_timeline teams timeline leaders projects]

    without = load_deferred(admin_teams_path, "Admin/Teams/Show", *deferred)
    lulu = without["teams"].find { it["pet"] == "lulu" }
    assert_equal [ 20, 30 ], lulu.values_at("xp", "transferred"), "teams always keep transfers apart"
    assert_equal [ 20, 150 ], without["leaders"].first.values_at("xp", "minutes")
    assert_equal 20, without["timeline"].last["lulu"]

    with = load_deferred(admin_teams_path(transfers: "1"), "Admin/Teams/Show", *deferred)
    assert_equal lulu, with["teams"].find { it["pet"] == "lulu" }, "who wins never changes"
    assert_equal [ 50, 270 ], with["leaders"].first.values_at("xp", "minutes")
    assert_equal [ projects(:station).public_id, 42, 210 ], with["projects"].first.values_at("id", "xp", "minutes")
    assert_equal 50, with["timeline"].last["lulu"]
    assert_equal 50, with["overall_timeline"].last["lulu"]

    users(:member).xp_entries.create!(kind: "transfer", amount: 5, day: Date.current)
    with = load_deferred(admin_teams_path(transfers: "1"), "Admin/Teams/Show", "leaders", "projects")
    assert_equal 55, with["leaders"].first["xp"], "a transfer entry without its transfer still counts for its person"
    assert_equal [ projects(:station).public_id, projects(:unlinked).public_id ], with["projects"].map { it["id"] }
  end

  test "a team's whole list of contributors loads a page at a time when asked for" do
    sign_in_as users(:admin)
    assert_nil inertia_props(admin_teams_path, "Admin/Teams/Show")["contributors"]

    list = load_deferred(admin_teams_path(team: "lulu", page: 1), "Admin/Teams/Show", "contributors")["contributors"]
    assert_equal "lulu", list["team"]
    assert_equal [ [ users(:member).public_id, 20 ] ], list["people"].map { [ it["user"]["id"], it["xp"] ] }
    assert_equal 1, list["pagy"]["count"]
  end

  test "paying a week that is over queues the payout once" do
    sign_in_as users(:admin)
    week = Week.of(Date.new(2026, 9, 7))

    assert_enqueued_with(job: TeamWinJob, args: [ week.start ]) { post admin_pay_teams_path(week: week.start.iso8601) }
    assert_redirected_to admin_teams_path(week: week.start.iso8601)
  end

  test "this week can't be paid yet" do
    sign_in_as users(:admin)
    assert_no_enqueued_jobs(only: TeamWinJob) { post admin_pay_teams_path }
  end

  test "members are turned away" do
    sign_in_as users(:member)
    get admin_teams_path
    assert_response :not_found
  end
end
