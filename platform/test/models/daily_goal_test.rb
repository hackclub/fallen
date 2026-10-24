require "test_helper"

# The daily goal on the home page. In UTC the deadline (11 December, 23:59 in New York) falls on 12 December, so from
# Wednesday 25 November there are 18 days left.
class DailyGoalTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 11, 25, 12)

  setup { travel_to NOW }

  test "only for someone with a pet who still needs xp, until the deadline" do
    assert_nil DailyGoal.for(users(:newcomer))
    assert DailyGoal.for(users(:admin))

    users(:admin).update_columns(xp: Evolution::STAGE_XP.last)
    assert_nil DailyGoal.for(users(:admin))

    travel_to DailyGoal::DEADLINE + 1.second
    assert_nil DailyGoal.for(users(:member))
  end

  test "spreads the xp left over the days left, and holds still while they journal today" do
    user = users(:admin)
    goal = DailyGoal.for(user)
    assert_equal 18, goal.days.count
    assert_equal (1000 / (8 / 60.0 * 18)).ceil, goal.minutes

    user.xp_entries.create!(kind: "journal", amount: 40, day: Date.new(2026, 11, 25))
    assert_equal goal.minutes, DailyGoal.for(user.reload).minutes

    user.xp_entries.create!(kind: "journal", amount: 40, day: Date.new(2026, 11, 24))
    assert_equal (960 / (8 / 60.0 * 18)).ceil, DailyGoal.for(user.reload).minutes
  end

  test "sami's best case raises the multiplier every monday, up to the most" do
    user = users(:admin)
    multipliers = 5 * 1.0 + 7 * 1.1 + 6 * 1.2
    assert_equal (1000 / (8 / 60.0 * multipliers)).ceil, DailyGoal.for(user).best_minutes

    user.update_columns(xp_multiplier: 1.5)
    goal = DailyGoal.for(user)
    assert_equal goal.minutes, goal.best_minutes
  end

  test "lulu's best case counts a bonus for every week paid by the deadline that can still get one" do
    user = users(:newcomer)
    user.update!(pet: "lulu")
    # Weeks from today: 25 November to 1 December, then 2 to 8 December. 9 to 15 December is paid too late.
    assert_equal ((1000 - 60) / (8 / 60.0 * 18)).ceil, DailyGoal.for(user).best_minutes

    # A first journal last Friday: this week (20 to 26 November) has one day journaled and two to go, so no bonus.
    # The next two end 3 and 10 December; the one after ends on the last day, too late to be paid.
    user.xp_entries.create!(kind: "journal", amount: 8, day: Date.new(2026, 11, 20))
    assert_equal ((992 - 60) / (8 / 60.0 * 18)).ceil, DailyGoal.for(user.reload).best_minutes
  end

  test "the egg picker's preview compares each pet for someone starting today, without a query" do
    user = users(:newcomer)
    preview = assert_no_queries { DailyGoal.preview(user) }
    assert_equal({ days_left: 18, minutes: (1000 / (8 / 60.0 * 18)).ceil,
                   best_minutes: { "lulu" => ((1000 - 60) / (8 / 60.0 * 18)).ceil, "sami" => (1000 / (8 / 60.0 * 19.9)).ceil } }, preview)

    travel_to DailyGoal::DEADLINE + 1.second
    assert_nil DailyGoal.preview(users(:newcomer))
  end
end
