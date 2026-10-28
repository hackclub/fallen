require "test_helper"

class Admin::StreakAdjustmentPolicyTest < ActiveSupport::TestCase
  test "admins change anyone's streak but their own and banned people's, undo what still stands, and members nothing" do
    excuse = ->(user) { StreakAdjustment.new(kind: "excuse", user: user) }
    assert Admin::StreakAdjustmentPolicy.new(users(:admin), excuse.(users(:member))).create?
    assert Admin::StreakAdjustmentPolicy.new(users(:admin), excuse.(nil)).create?, "an incident"
    assert_not Admin::StreakAdjustmentPolicy.new(users(:admin), excuse.(users(:admin))).create?
    assert_equal "Banned Person is banned.", Admin::StreakAdjustmentPolicy.new(users(:admin), excuse.(users(:banned))).why_not
    assert_not Admin::StreakAdjustmentPolicy.new(users(:member), excuse.(users(:newcomer))).create?

    undone = excuse.(users(:member)).tap { it.discarded_at = Time.current }
    assert_not Admin::StreakAdjustmentPolicy.new(users(:admin), undone).destroy?
    assert_empty Admin::StreakAdjustmentPolicy::Scope.new(users(:member), StreakAdjustment).resolve
  end
end
