require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "public ids round trip" do
    user = users(:member)
    assert_match(/\Ausr_[A-Za-z0-9]{6,}\z/, user.public_id)
    assert_equal user, User.find_by_public_id!(user.public_id)
    assert_nil User.find_by_public_id("nope_#{user.hashid}")
  end

  test "roles" do
    user = users(:member)
    assert_not user.admin?
    user.add_role(:admin)
    assert user.reload.admin?
    assert user.staff?
    user.remove_role(:admin)
    assert_not user.reload.admin?
  end

  test "rejects unknown roles" do
    user = users(:member)
    user.roles = [ "superuser" ]
    assert_not user.valid?
    assert_includes user.errors[:roles].first, "superuser"
  end

  test "assign_from_hca fills profile fields" do
    user = User.new(hca_id: "x")
    user.assign_from_hca({ "primary_email" => "zrl@hackclub.com", "first_name" => "Zach", "last_name" => "L", "slack_id" => "U123", "verification_status" => "verified", "birthday" => "1990-01-01" }, "tok")
    assert user.save
    assert_equal "Zach L", user.display_name
    assert_equal "U123", user.slack_id
    assert user.is_adult
    assert_equal [ "user" ], user.roles
    assert_equal "tok", user.hca_token
  end
end
