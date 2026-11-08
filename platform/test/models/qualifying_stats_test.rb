require "test_helper"

class QualifyingStatsTest < ActiveSupport::TestCase
  setup { travel_to Time.utc(2026, 11, 10, 17) }

  test "locking in is journaling LOCK_IN_HOURS in the last LOCK_IN_DAYS, with each person's last journal" do
    now = Time.utc(2026, 11, 10, 17)
    member = users(:member)
    Journal.update_all(created_at: now - 1.day)
    journals(:first).update_columns(duration_minutes: QualifyingStats::LOCK_IN_HOURS * 60)
    journals(:web_only).update_columns(created_at: now - QualifyingStats::LOCK_IN_DAYS.days - 1.hour)

    assert_equal({ member.id => QualifyingStats::LOCK_IN_HOURS * 60 }, QualifyingStats.locked_in(User.on_a_team, now))

    activity = QualifyingStats.journal_activity([ member.id, users(:admin).id ], now)
    assert_equal now - 1.day, activity[:last_journals][member.id]
    assert_equal QualifyingStats::LOCK_IN_HOURS * 60, activity[:recent_minutes][member.id], "the older journal left out"
    assert_equal member.journals.kept.sum(:duration_minutes), activity[:total_minutes][member.id]

    journals(:first).update_columns(duration_minutes: 30)
    assert_empty QualifyingStats.locked_in(User.on_a_team, now)
  end

  test "the summary counts each status and who has journaled, and the extra tabs" do
    day = Date.new(2026, 11, 10)
    XpEntry.delete_all
    users(:admin).update_columns(xp: QualifyingPace.goal_xp)
    users(:member).update_columns(xp: QualifyingPace.on_track_xp("lulu", day - 1))
    Journal.update_all(created_at: 5.days.ago)
    people = QualifyingPace.with_status(User.on_a_team, day)

    summary = QualifyingStats.summary(people, day)
    assert_equal 2, summary[:statuses]["on_track"][:all]
    assert_equal 1, summary[:statuses]["on_track"][:builders], "only the member has journaled"
    assert_equal 1, summary[:recently_inactive], "the member, no journal in QUIET_DAYS"
    member_hours = users(:member).journals.kept.sum(:duration_minutes) / 60.0
    days = day..QualifyingPace.deadline
    left = QualifyingPace.goal_xp - users(:member).xp - QualifyingPace.bonus_xp("lulu", days)
    expected = (member_hours + left * days.count / QualifyingPace.hourly_xp("lulu", days, day)).round
    assert_equal({ average: expected, low: expected, high: expected }, summary[:hours_to_qualify],
      "the member is on track: their hours, then the rest with Lulu's bonuses to come")

    member = people.find_by(id: users(:member).id)
    assert_in_delta member_hours + left * days.count / QualifyingPace.hourly_xp("lulu", days, day),
      QualifyingStats.hours_to_qualify(member, member_hours * 60, day), 0.001, "one person's, as the average counts it"
    sami = users(:admin)
    sami.update_columns(xp: 100, xp_multiplier: 1.3)
    sami_days = QualifyingStats.days_left(day)
    assert_in_delta 2 + 900 * sami_days.count / QualifyingPace.hourly_xp("sami", sami_days, day, 1.3.to_d),
      QualifyingStats.hours_to_qualify(sami, 120, day), 0.001, "a Sami streak rises from the multiplier they have"
    sami.update_columns(xp: QualifyingPace.goal_xp)

    assert_equal [ "Member Person" ], QualifyingStats.tab(people, "recently_inactive", day).pluck(:display_name)

    users(:member).update_columns(xp: 1)
    assert_nil QualifyingStats.summary(QualifyingPace.with_status(User.on_a_team, day), day)[:hours_to_qualify],
      "off track doesn't count"
  end

  test "the hours funnel counts who has journaled each step's hours, up to the goal's" do
    funnel = QualifyingStats.hours_funnel(User.on_a_team)
    assert_equal "team", funnel.first[:key]
    assert_equal User.on_a_team.where(QualifyingStats::BUILDER).count, funnel.second[:count], "then the builders"
    assert_equal User.on_a_team.count, funnel.first[:count]
    assert_equal "#{QualifyingStats.goal_hours}h", funnel.last[:key]
    assert_equal 1, funnel.find { it[:key] == "1h" }[:count], "the member's slack and web journals, transfers left out"
  end
end
