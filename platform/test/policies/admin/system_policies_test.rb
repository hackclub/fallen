require "test_helper"

# /admin/insights, /admin/jobs and /admin/flags: admins only, everything else fails closed.
class Admin::SystemPoliciesTest < ActiveSupport::TestCase
  test "only admins read and act on insights, jobs and flags" do
    { Admin::InsightsPolicy => %i[show?], Admin::JobPolicy => %i[index? show? update? destroy?],
      Admin::FlagPolicy => %i[index? show? create? update? destroy?] }.each do |policy, actions|
      actions.each do |action|
        assert policy.new(users(:admin), nil).public_send(action), "#{policy}##{action} for admins"
        assert_not policy.new(users(:member), nil).public_send(action), "#{policy}##{action} for members"
        assert_not policy.new(nil, nil).public_send(action), "#{policy}##{action} for guests"
      end
    end
  end

  test "the job scope is empty for anyone but admins" do
    assert_empty Admin::JobPolicy::Scope.new(users(:member), SolidQueue::Job).resolve.to_a
    assert_equal SolidQueue::Job.all.to_sql, Admin::JobPolicy::Scope.new(users(:admin), SolidQueue::Job).resolve.to_sql
  end
end
