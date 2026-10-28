require "test_helper"

# XP: the ledger (XpEntry), the pet's growth (Evolution) and the teams' weeks (Team, closed by CloseWeekJob and SettleLuluWeeksJob).
class XpTest < ActiveSupport::TestCase
  test "a journal's entry follows its hours and is worth at least 1 xp" do
    user = users(:member)
    journal = projects(:station).journals.create!(user: user, body: journal_text("x"), duration: "1.5", images: [ photo ])
    assert_equal 12, journal.xp
    assert_equal 32, user.reload.xp

    # Hours are fixed once logged (Journal#hours_unchanged); one saved without them can be given them.
    journal.update_column(:duration_minutes, nil)
    journal.update!(duration: "0.05")
    assert_equal 1, journal.reload.xp
    journal.update_column(:duration_minutes, nil)
    journal.update!(duration: "3h", images: [ photo, photo ])
    assert_equal 24, journal.reload.xp
    assert_equal 44, user.reload.xp

    journal.discard
    assert journal.reload.xp_entry.discarded?, "kept in the ledger, not removed"
    assert_nil journal.xp
    assert_equal 20, user.reload.xp
    journal.undiscard
    assert_equal 44, user.reload.xp
    assert_equal 24, journal.reload.xp
  end

  test "deleting a project takes back its journals' xp and the early-bird bonus, keeping the entries" do
    user = users(:newcomer)
    travel_to Project::EARLY_BIRD_UNTIL - 1.hour do
      project = user.projects.create!(title: "First")
      project.journals.create!(user: user, body: journal_text("x"), duration: "1h", images: [ photo ])
      assert_equal Project::EARLY_BIRD_BONUS + 8, user.reload.xp

      assert_no_difference -> { XpEntry.count } do
        project.discard
      end
      assert_equal 0, user.reload.xp
      assert_equal 2, user.xp_entries.discarded.count
      assert_equal 0, XpEntry.during(Week.of(user.local_date)).where(user: user).sum(:amount)
    end
  end

  test "a journal keeps the multiplier it was saved with" do
    user = users(:admin)
    user.update!(xp_multiplier: 1.5)
    journal = projects(:admins).journals.create!(user: user, body: journal_text("x"), duration: "1h", images: [ photo ])
    assert_equal 12, journal.xp

    user.update!(xp_multiplier: 1.0)
    journal.update_column(:duration_minutes, nil)
    journal.update!(duration: "2h")
    assert_equal 24, journal.reload.xp
    assert_equal 1.5, journal.xp_entry.multiplier
  end

  test "the entry's day is the person's own calendar day" do
    user = users(:member)
    user.update!(timezone: "Pacific/Auckland")
    travel_to Time.utc(2026, 10, 20, 13, 0) do
      journal = projects(:station).journals.create!(user: user, body: journal_text("x"), duration: "1h", images: [ photo ])
      assert_equal Date.new(2026, 10, 21), journal.xp_entry.day
    end
  end

  test "pets hatch with the first journal and evolve with xp, the last form needing an approved project" do
    user = users(:newcomer)
    user.update!(pet: "lulu")
    assert_equal 0, user.pet_form
    assert_equal 1, user.stage

    user.update_column(:xp, 1)
    assert_equal 1, user.pet_form
    assert_equal 200, user.next_stage_xp
    user.update_column(:xp, 200)
    assert_equal 2, user.pet_form
    user.update_column(:xp, 999)
    assert_equal 3, user.pet_form
    assert_equal 1000, user.next_stage_xp

    user.update_column(:xp, 1000)
    assert_equal 3, user.pet_form
    assert_nil user.next_stage_xp
    user.projects.create!(title: "Done", approved: true)
    assert_equal 4, user.pet_form
  end

  test "approval is a timestamp that stays put" do
    project = projects(:station)
    project.update!(approved: "1")
    at = project.approved_at
    project.update!(approved: true)
    assert_equal at, project.approved_at
    project.update!(approved: "0")
    assert_nil project.approved_at
  end

  test "a first project started before the deadline earns the early bird bonus once" do
    user = users(:newcomer)
    travel_to Project::EARLY_BIRD_UNTIL - 1.hour do
      user.projects.create!(title: "One")
      user.projects.create!(title: "Two")
    end
    assert_equal [ Project::EARLY_BIRD_BONUS ], user.xp_entries.where(kind: "early_bird").pluck(:amount)
    assert_equal Project::EARLY_BIRD_BONUS, user.reload.xp

    late = users(:admin)
    travel_to Project::EARLY_BIRD_UNTIL + 1.minute do
      late.projects.create!(title: "Late")
    end
    assert_not late.xp_entries.exists?(kind: "early_bird")
  end

  test "the first new journal that says stupendous, in any case, earns the bonus once and keeps it" do
    user = users(:newcomer)
    project = user.projects.create!(title: "One")
    before = user.reload.xp

    project.journals.create!(user: user, body: journal_text("It went stupendusly"), duration: "1h", images: [ photo ])
    assert_not user.xp_entries.exists?(kind: "stupendous"), "a typo doesn't count"

    first = project.journals.create!(user: user, body: journal_text("A #STUPENDOUSLY good day"), duration: "1h", images: [ photo ])
    project.journals.create!(user: user, body: journal_text("Stupendous again"), duration: "1h", images: [ photo ])
    assert_equal [ [ XpEntry::STUPENDOUS_BONUS, first.id ] ], user.xp_entries.where(kind: "stupendous").pluck(:amount, :source_id)
    assert_equal before + (3 * 8) + XpEntry::STUPENDOUS_BONUS, user.reload.xp
    assert_equal 8, first.reload.xp, "the journal's own entry is still its hours"

    first.discard
    assert user.xp_entries.kept.exists?(kind: "stupendous"), "kept when the journal goes"
  end

  test "adding stupendous to a journal later earns nothing" do
    user = users(:member)
    journal = projects(:station).journals.create!(user: user, body: journal_text("x"), duration: "1h", images: [ photo ])
    journal.update!(body: journal_text("Stupendous"))
    assert_not user.xp_entries.exists?(kind: "stupendous")
  end

  test "lulu's weeks start on the first journal and pay a bonus for five journal days, once, after the week ends" do
    user = users(:member)
    first = Date.new(2026, 9, 10) # a Thursday
    journal_on(user, [ first, first + 1, first + 2, first + 3 ])
    week = user.team.week(first + 6)
    assert_equal first..first + 6, week.days
    assert_equal first + 7, user.team.week(first + 7).start

    user.team.settle(first + 7)
    assert_not user.xp_entries.exists?(kind: "weekly_bonus")

    journal_on(user, [ first + 6 ])
    user.team.settle(first + 6)
    assert_not user.xp_entries.exists?(kind: "weekly_bonus"), "not until the week has ended"

    (7..13).each { |n| user.team.settle(first + n) }
    assert_equal [ Team::Lulu::WEEKLY_BONUS ], user.xp_entries.where(kind: "weekly_bonus").pluck(:amount)
    assert_equal first + 6, user.xp_entries.find_by(kind: "weekly_bonus").day
    assert_equal 1, user.xp_entries.find_by(kind: "weekly_bonus").versions.count, "the ledger is audited"

    journal_on(user, [ first - 1 ])
    user.team.settle(first + 6)
    assert_equal 1, user.xp_entries.where(kind: "weekly_bonus").count, "a week that moved is not paid again"
  end

  test "settling pays only team lulu" do
    first = Date.new(2026, 9, 10)
    journal_on(users(:member), (first..first + 4).to_a)
    journal_on(users(:admin), (first..first + 4).to_a)

    travel_to (first + 8).in_time_zone(users(:member).timezone).change(hour: 12) do
      2.times { SettleLuluWeeksJob.perform_now }
    end
    assert_equal 1, users(:member).xp_entries.where(kind: "weekly_bonus").count
    assert_not users(:admin).xp_entries.exists?(kind: "weekly_bonus")
  end

  test "sami raises the multiplier for a week without gaps, spends freezes on missed days and resets after them" do
    user = users(:admin)
    week = Week.of(Date.new(2026, 9, 7))
    user.team.close_week(week)
    assert_equal 1.0, user.reload.xp_multiplier, "nothing happens before the first journal"

    journal_on(user, week.days.to_a - [ week.start ])
    2.times { user.team.close_week(week) }
    assert_equal 1.15, user.reload.xp_multiplier, "the streak starts with the first journal"
    assert_equal 3, user.streak_freezes
    assert_equal 1, user.streak_weeks.count

    journal_on(user, week.days.map { |day| day + 7 }.first(5))
    user.team.close_week(Week.of(week.start + 7))
    assert_equal 1.3, user.reload.xp_multiplier
    assert_equal 1, user.streak_freezes

    journal_on(user, [ week.start + 14 ])
    user.team.close_week(Week.of(week.start + 14))
    assert_equal 1.0, user.reload.xp_multiplier
    assert_equal 0, user.streak_freezes

    user.update!(xp_multiplier: 1.7)
    journal_on(user, week.days.map { |day| day + 21 })
    user.team.close_week(Week.of(week.start + 21))
    assert_equal Team::Sami::MAX_MULTIPLIER, user.reload.xp_multiplier
  end

  test "closing a week pays the winning team's contributors" do
    week = Week.of(Date.new(2026, 9, 7))
    journal_on(users(:member), [ week.start ], hours: "5h")
    journal_on(users(:admin), [ week.start ], hours: "1h")
    users(:newcomer).update!(pet: "lulu")

    assert_equal({ "lulu" => 40, "sami" => 8 }, XpEntry.team_totals(week))
    2.times { CloseWeekJob.perform_now(week.finish) }
    assert_equal [ Team::WIN_BONUS ], users(:member).xp_entries.where(kind: "team_win").pluck(:amount)
    assert_not users(:newcomer).xp_entries.exists?(kind: "team_win"), "only members who earned xp that week"
    assert_not users(:admin).xp_entries.exists?(kind: "team_win")
    assert_equal 20 + 40 + Team::WIN_BONUS, users(:member).reload.xp
  end

  test "a week is won once, even if the other team pulls ahead before the job runs again" do
    week = Week.of(Date.new(2026, 9, 7))
    journal_on(users(:member), [ week.start ], hours: "5h")
    CloseWeekJob.perform_now(week.finish)

    journal_on(users(:admin), [ week.start + 1 ], hours: "10h")
    CloseWeekJob.perform_now(week.finish)
    assert_equal [ users(:member) ], XpEntry.where(kind: "team_win").map(&:user)
  end

  private

  def journal_on(user, days, hours: "1h")
    project = user.projects.first || user.projects.create!(title: "Thing")
    days.each do |day|
      travel_to day.in_time_zone(user.timezone).change(hour: 12) do
        project.journals.create!(user: user, body: journal_text("on #{day}") * 2, duration: hours, images: Array.new(Journal.new(duration: hours).images_needed) { photo })
      end
    end
  end
end
