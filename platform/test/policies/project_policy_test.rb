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

  test "an owner can't delete a project someone they took off the team has journals on" do
    project = projects(:station)
    assert ProjectPolicy.new(users(:member), project).destroy?

    # Written while they were on the team, which they no longer are.
    project.journals.new(user: users(:newcomer), body: "From before they were taken off", source: "slack").save!(validate: false)
    assert_not ProjectPolicy.new(users(:member), project.reload).destroy?
  end

  test "journals need slack connected or skipped, projects do not" do
    member = users(:member)
    member.disconnect_slack!
    assert ProjectPolicy.new(member, Project).create?
    assert_not JournalPolicy.new(member, projects(:station).journals.build(user: member)).create?
    assert JournalPolicy.new(member, journals(:first)).update?

    member.skip_slack!
    assert JournalPolicy.new(member, projects(:station).journals.build(user: member)).create?
  end

  test "journals belong to the project owner" do
    journal = projects(:station).journals.build(user: users(:member))
    assert JournalPolicy.new(users(:member), journal).create?
    assert_not JournalPolicy.new(users(:admin), journal).create?
    assert JournalPolicy.new(users(:member), journals(:first)).destroy?
    assert_not JournalPolicy.new(users(:admin), journals(:first)).destroy?
  end
end
