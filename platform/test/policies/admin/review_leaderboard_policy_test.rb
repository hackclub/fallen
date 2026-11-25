require "test_helper"

class Admin::ReviewLeaderboardPolicyTest < ActiveSupport::TestCase
  test "only admins see it" do
    assert Admin::ReviewLeaderboardPolicy.new(users(:admin), :review_leaderboard).show?
    assert_not Admin::ReviewLeaderboardPolicy.new(users(:member), :review_leaderboard).show?
  end
end
