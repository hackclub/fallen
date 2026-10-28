require "test_helper"

class AdminStreaksTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  WEEK = Week.of(Date.new(2026, 9, 7))

  setup { sign_in_as users(:admin) }

  test "a person's page draws their weeks and previews a restore before it is made" do
    user = broken_sami
    travel_to(WEEK.start + 16) do
      streak = load_deferred(admin_user_path(user), "Admin/Users/Show", "streak")["streak"]
      assert_equal [ "broken", "kept", "open", "open" ], streak["rows"].pluck("status")
      assert_equal %w[journal journal missed missed missed missed missed], streak["rows"].first["days"].pluck("state")
      assert_equal [ 1.15, 0 ], streak.values_at("multiplier", "freezes")

      get admin_user_path(user), params: { preview: { kind: "excuse", starts_on: (WEEK.start + 2).iso8601, ends_on: (WEEK.start + 4).iso8601 } },
                                 headers: partial_headers("Admin/Users/Show", "streak_preview")
      plan = response.parsed_body.dig("props", "streak_preview", "plan")
      assert_equal [ [ 1.15, 1.3 ], [ 0, 1 ], 1 ], plan.values_at("multiplier", "freezes", "restored")
      assert_equal [ %w[broken frozen], %w[kept kept] ], plan["weeks"].pluck("outcome")
      assert_equal [ 1.15, 1.3 ], plan["weeks"].last["multiplier"]

      get admin_user_path(user), params: { preview: { kind: "excuse", starts_on: (WEEK.start + 4).iso8601, ends_on: WEEK.start.iso8601 } },
                                 headers: partial_headers("Admin/Users/Show", "streak_preview")
      assert_equal [ "Ends on must be on or after the first day" ], response.parsed_body.dig("props", "streak_preview", "errors")
    end
  end

  test "restoring a broken week saves who and why, says what changed, DMs when asked, and can be undone" do
    user = broken_sami
    travel_to(WEEK.start + 16) do
      post admin_streak_adjustments_path, params: { adjustment: { kind: "excuse", user_id: user.public_id, starts_on: (WEEK.start + 2).iso8601,
                                                                  ends_on: (WEEK.start + 4).iso8601, reason: "Slack was down", notify: "1", message: "Sorry!" } }
    end
    assert_redirected_to admin_user_path(user)
    assert_equal "Excused September 9 to 11 for New Person: 1.15x → 1.30x, 0 → 1 freezes, +8 XP. They will get a DM.", flash[:notice]
    adjustment = user.streak_adjustments.sole
    assert_equal [ users(:admin), "Slack was down", "Sorry!" ], adjustment.values_at(:admin, :reason, :message)
    assert_enqueued_with(job: StreakAdjustedJob, args: [ adjustment ])
    assert_equal [ 1.3, 1 ], [ user.reload.xp_multiplier, user.streak_freezes ]

    delete admin_streak_adjustment_path(adjustment)
    assert_equal "Undone.", flash[:notice]
    assert_equal [ 1.15, 0 ], [ user.reload.xp_multiplier, user.streak_freezes ]
  end

  test "a form that doesn't hold up changes nothing, and nobody restores their own streak" do
    user = broken_sami
    post admin_streak_adjustments_path, params: { adjustment: { kind: "freezes", user_id: user.public_id, freezes: "2", reason: "" } }
    assert_response :redirect
    assert_equal 0, user.reload.streak_freezes

    post admin_streak_adjustments_path, params: { adjustment: { kind: "freezes", user_id: users(:admin).public_id, freezes: "2", reason: "Mine" } }
    assert_equal 3, users(:admin).reload.streak_freezes
    assert_not StreakAdjustment.exists?
  end

  test "the streaks page lists broken weeks, incidents and every change, and makes incidents" do
    user = broken_sami
    props = load_deferred(admin_streaks_path, "Admin/Streaks/Index", "rows", "pagy", "weeks", "counts")
    assert_equal [ user.public_id ], props["rows"].map { it.dig("user", "id") }
    assert_equal [ { "start" => WEEK.start.iso8601, "count" => 1 } ], props["weeks"]
    assert_equal({ "broken" => 1, "incidents" => 0 }, props["counts"])

    get admin_streaks_path, params: { preview: { starts_on: (WEEK.start + 2).iso8601, ends_on: (WEEK.start + 4).iso8601 } },
                            headers: partial_headers("Admin/Streaks/Index", "incident_preview")
    assert_equal [ 1, 1, 1 ], response.parsed_body.dig("props", "incident_preview").values_at("weeks", "missed", "broken")

    post admin_streak_adjustments_path, params: { adjustment: { kind: "excuse", starts_on: (WEEK.start + 2).iso8601, ends_on: (WEEK.start + 4).iso8601,
                                                                reason: "Slack was down" } }
    assert_redirected_to admin_streaks_path(tab: "incidents")
    incident = StreakAdjustment.incidents.sole
    assert_enqueued_with(job: RejudgeStreaksJob, args: [ incident, (WEEK.start + 2).iso8601, (WEEK.start + 4).iso8601 ])

    rows = load_deferred(admin_streaks_path(tab: "incidents"), "Admin/Streaks/Index", "rows")["rows"]
    assert_equal [ incident.public_id ], rows.pluck("id")
    assert_nil rows.first["user"]
    assert_equal 1, load_deferred(admin_streaks_path(tab: "log"), "Admin/Streaks/Index", "rows")["rows"].size
  end

  test "members can't see or change streaks" do
    sign_in_as users(:member)
    get admin_streaks_path
    assert_response :not_found
  end

  private

  def partial_headers(component, *props)
    { "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version.to_s, "X-Inertia-Partial-Component" => component,
      "X-Inertia-Partial-Data" => props.join(",") }
  end

  # Week 1 breaks (two journal days), week 2 is kept at 1x, and week 3 has begun at 1.15x.
  def broken_sami
    user = users(:newcomer).tap { it.update_columns(pet: "sami") }
    project = user.projects.create!(title: "Thing")
    journal = ->(day) do
      travel_to(day.in_time_zone(user.timezone).change(hour: 12)) do
        project.journals.create!(user: user, body: journal_text("on #{day}") * 2, duration: "1h", images: Array.new(Journal.new(duration: "1h").images_needed) { photo })
      end
    end
    close = ->(week) { travel_to((week.finish + 1).in_time_zone("UTC").change(hour: 10)) { user.reload.team.close_week(week) } }

    [ WEEK.start, WEEK.start + 1 ].each(&journal)
    close.(WEEK)
    Week.of(WEEK.start + 7).days.each(&journal)
    close.(Week.of(WEEK.start + 7))
    journal.(WEEK.start + 14)
    user.reload
  end
end
