require "test_helper"

class ProjectPolicyTest < ActiveSupport::TestCase
  test "owners manage their projects, staff can look" do
    member = users(:member)
    assert ProjectPolicy.new(member, projects(:station)).show?
    assert ProjectPolicy.new(member, projects(:station)).update?
    assert_not ProjectPolicy.new(member, projects(:admins)).show?
    assert ProjectPolicy.new(users(:admin), projects(:station)).show?
    assert_not ProjectPolicy.new(users(:admin), projects(:station)).update?
    assert_equal [ projects(:station), projects(:unlinked) ].sort, ProjectPolicy::Scope.new(member, Project).resolve.sort
  end

  test "journals need slack connected, projects do not" do
    member = users(:member)
    member.disconnect_slack!
    assert ProjectPolicy.new(member, Project).create?
    assert_not JournalPolicy.new(member, projects(:station).journals.build(user: member)).create?
    assert JournalPolicy.new(member, journals(:first)).update?
  end

  test "journals belong to the project owner" do
    journal = projects(:station).journals.build(user: users(:member))
    assert JournalPolicy.new(users(:member), journal).create?
    assert_not JournalPolicy.new(users(:admin), journal).create?
    assert JournalPolicy.new(users(:member), journals(:first)).destroy?
    assert_not JournalPolicy.new(users(:admin), journals(:first)).destroy?
  end
end
