require "test_helper"

class Admin::ProjectTransferPolicyTest < ActiveSupport::TestCase
  test "admins decide pending transfers once; members see none" do
    transfer = project_transfers(:stardance)
    assert Admin::ProjectTransferPolicy.new(users(:admin), transfer).approve?
    assert Admin::ProjectTransferPolicy.new(users(:admin), transfer).refetch?
    assert_not Admin::ProjectTransferPolicy.new(users(:admin), project_transfers(:stranger)).refetch?, "no fetcher for it"
    assert_not Admin::ProjectTransferPolicy.new(users(:member), transfer).show?

    transfer.status = "approved"
    assert_not Admin::ProjectTransferPolicy.new(users(:admin), transfer).approve?
    assert_not Admin::ProjectTransferPolicy.new(users(:admin), transfer).reject?
    assert Admin::ProjectTransferPolicy.new(users(:admin), transfer).reach_out?, "reaching out can follow the decision"
    assert_empty Admin::ProjectTransferPolicy::Scope.new(users(:member), ProjectTransfer).resolve
  end

  test "reviewers decide transfers but don't pull the form; design reviewers see none" do
    reviewer = users(:member).tap { it.roles = %w[user reviewer] }
    transfer = project_transfers(:stardance)
    assert Admin::ProjectTransferPolicy.new(reviewer, transfer).show?
    assert Admin::ProjectTransferPolicy.new(reviewer, transfer).approve?
    assert Admin::ProjectTransferPolicy.new(reviewer, transfer).reject?
    assert Admin::ProjectTransferPolicy.new(reviewer, transfer).reach_out?
    assert Admin::ProjectTransferPolicy.new(reviewer, transfer).undo_reach_out?
    assert_not Admin::ProjectTransferPolicy.new(reviewer, ProjectTransfer).sync?
    assert_not_empty Admin::ProjectTransferPolicy::Scope.new(reviewer, ProjectTransfer).resolve

    design_reviewer = users(:member).tap { it.roles = %w[user design_reviewer] }
    assert_not Admin::ProjectTransferPolicy.new(design_reviewer, transfer).show?
    assert_not Admin::ProjectTransferPolicy.new(design_reviewer, transfer).reach_out?
    assert_not Admin::ProjectTransferPolicy.new(design_reviewer, transfer).undo_reach_out?
  end
end
