require "test_helper"

# /admin/insights, /admin/stats, /admin/teams, /admin/jobs and /admin/flags: admins only, everything else fails closed.
class Admin::SystemPoliciesTest < ActiveSupport::TestCase
  test "only admins read and act on insights, stats, teams, jobs and flags" do
    { Admin::InsightsPolicy => %i[show?], Admin::StatsPolicy => %i[show?],
      Admin::TeamRacePolicy => %i[show?], Admin::JobPolicy => %i[index? show? update? destroy?],
      Admin::FlagPolicy => %i[index? show? create? update? destroy?] }.each do |policy, actions|
      actions.each do |action|
        assert policy.new(users(:admin), nil).public_send(action), "#{policy}##{action} for admins"
        assert_not policy.new(users(:member), nil).public_send(action), "#{policy}##{action} for members"
        assert_not policy.new(nil, nil).public_send(action), "#{policy}##{action} for guests"
      end
    end
  end

  test "a week's win is paid only once it is over and not paid yet" do
    over = TeamRace.new(Week.of(Date.new(2026, 9, 7)))
    assert Admin::TeamRacePolicy.new(users(:admin), over).pay?
    assert_not Admin::TeamRacePolicy.new(users(:member), over).pay?
    assert_not Admin::TeamRacePolicy.new(users(:admin), TeamRace.new(Week.of(Date.current))).pay?, "still running"

    users(:member).xp_entries.create!(kind: "team_win", amount: Team::WIN_BONUS, day: over.week.finish)
    assert_not Admin::TeamRacePolicy.new(users(:admin), over).pay?, "already paid"
  end

  test "the job scope is empty for anyone but admins" do
    assert_empty Admin::JobPolicy::Scope.new(users(:member), SolidQueue::Job).resolve.to_a
    assert_equal SolidQueue::Job.all.to_sql, Admin::JobPolicy::Scope.new(users(:admin), SolidQueue::Job).resolve.to_sql
  end
end
