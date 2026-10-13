require "test_helper"

class Admin::ProjectPolicyTest < ActiveSupport::TestCase
  test "only admins see every project" do
    assert Admin::ProjectPolicy.new(users(:admin), projects(:station)).show?
    assert_not Admin::ProjectPolicy.new(users(:member), projects(:station)).show?
    assert_equal Project.count, Admin::ProjectPolicy::Scope.new(users(:admin), Project).resolve.count
    assert_empty Admin::ProjectPolicy::Scope.new(users(:member), Project).resolve
  end
end
