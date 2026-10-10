require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  test "admins manage other users but not themselves" do
    admin = users(:admin)
    assert UserPolicy.new(admin, users(:member)).update?
    assert_not UserPolicy.new(admin, admin).update?
    assert UserPolicy.new(admin, admin).show?
    assert UserPolicy.new(admin, User).index?
  end

  test "members only see themselves" do
    member = users(:member)
    assert UserPolicy.new(member, member).show?
    assert_not UserPolicy.new(member, users(:admin)).show?
    assert_not UserPolicy.new(member, users(:admin)).update?
    assert_equal [ member ], UserPolicy::Scope.new(member, User).resolve.to_a
  end
end
