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
    assert_empty Admin::ProjectTransferPolicy::Scope.new(users(:member), ProjectTransfer).resolve
  end
end
