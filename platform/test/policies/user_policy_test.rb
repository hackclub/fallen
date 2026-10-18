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

  test "people choose only their own pet" do
    member = users(:member)
    assert UserPolicy.new(member, member).choose_pet?
    assert_not UserPolicy.new(member, users(:admin)).choose_pet?
    assert_not UserPolicy.new(users(:admin), member).choose_pet?
  end

  test "only the person themselves watching their hatch counts" do
    member = users(:member)
    assert UserPolicy.new(member, member).watch_hatch?
    assert_not UserPolicy.new(users(:admin), member).watch_hatch?
    Current.true_user = users(:admin)
    assert_not UserPolicy.new(member, member).watch_hatch?
  ensure
    Current.true_user = nil
  end
end
