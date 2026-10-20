require "test_helper"

class FeatureFlagTest < ActiveSupport::TestCase
  test "users are actors by public_id and belong to the groups their roles put them in" do
    assert_equal users(:member).public_id, users(:member).flipper_id
    assert users(:admin).flipper_group?(:admins)
    assert users(:admin).flipper_group?(:staff)
    assert_not users(:member).flipper_group?(:staff)
    assert users(:member).flipper_group?(:verified)
    assert_not users(:member).flipper_group?(:trial)
  end

  test "an update changes only what it names" do
    Flipper.enable_group(:beta, :admins)
    flag = FeatureFlag.find!("beta").update!(percentage_of_time: 10)

    assert_equal [ "admins" ], flag.groups
    assert_equal 10, flag.percentage_of_time
    assert_equal "on for admins and 10% of checks", flag.summary
  end

  test "groups that aren't registered are ignored" do
    Flipper.add(:beta)
    assert_empty FeatureFlag.find!("beta").update!(groups: [ "everyone_ever" ]).groups
  end

  test "names are lowercase words joined by underscores" do
    assert FeatureFlag.new("new_shop_2").valid?
    assert_not FeatureFlag.new("2shop").valid?
    assert_not FeatureFlag.new("New-Shop").valid?
  end
end
