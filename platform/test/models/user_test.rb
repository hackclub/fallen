require "test_helper"

# == Schema Information
#
# Table name: users
#
#  id                      :bigint           not null, primary key
#  avatar                  :string
#  discarded_at            :datetime
#  display_name            :string           not null
#  email                   :string           not null
#  hatch_seen_at           :datetime
#  hca_token               :text
#  is_adult                :boolean          default(FALSE), not null
#  is_banned               :boolean          default(FALSE), not null
#  lapse_synced_at         :datetime
#  lapse_token             :text
#  last_seen_at            :datetime
#  pet                     :string
#  pet_switched_at         :datetime
#  roles                   :string           default([]), not null, is an Array
#  signup_source           :jsonb            not null
#  slack_skipped_at        :datetime
#  slack_user_token        :text
#  slack_user_token_scopes :string
#  soft_signup             :string
#  streak_freezes          :integer          default(3), not null
#  timezone                :string           default("UTC"), not null
#  verification_status     :string
#  xp                      :integer          default(0), not null
#  xp_multiplier           :decimal(2, 1)    default(1.0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  hca_id                  :string
#  slack_id                :string
#
# Indexes
#
#  index_users_on_airtable_synced_at  (airtable_synced_at)
#  index_users_on_created_at          (created_at)
#  index_users_on_discarded_at        (discarded_at)
#  index_users_on_email               (email)
#  index_users_on_hca_id              (hca_id) UNIQUE
#  index_users_on_last_seen_at        (last_seen_at)
#  index_users_on_roles               (roles) USING gin
#  index_users_on_slack_id            (slack_id)
#
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

  test "avatar comes from Cachet when the user has a Slack id" do
    user = users(:member)
    assert_equal "https://cachet.hackclub.com/users/U0MEMBER/r", user.avatar_url

    user.slack_id = nil
    user.avatar = "https://example.com/me.png"
    assert_equal "https://example.com/me.png", user.avatar_url

    user.avatar = nil
    assert_equal User::FALLBACK_AVATAR, user.avatar_url
  end

  test "rejects unknown roles" do
    user = users(:member)
    user.roles = [ "superuser" ]
    assert_not user.valid?
    assert_includes user.errors[:roles].first, "superuser"
  end

  test "sync_slack_profile! keeps legacy zone names Slack sends and skips ones Ruby cannot load" do
    user = users(:member)
    with_fake_slack do |slack|
      tz = "Asia/Katmandu"
      slack.define_singleton_method(:users_info) { |user:| Slack::Messages::Message.new("user" => { "tz" => tz, "profile" => { "display_name" => "Orpheus" } }) }

      user.sync_slack_profile!
      assert_equal "Asia/Katmandu", user.reload.timezone
      assert_equal "Asia/Kathmandu", ActiveSupport::TimeZone[user.timezone].tzinfo.canonical_identifier

      tz = "Mars/Olympus_Mons"
      user.sync_slack_profile!
      assert_equal "Asia/Katmandu", user.reload.timezone
    end
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
