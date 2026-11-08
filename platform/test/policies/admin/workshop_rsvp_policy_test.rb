require "test_helper"

class Admin::WorkshopRsvpPolicyTest < ActiveSupport::TestCase
  setup { travel_to Time.zone.parse("2026-11-04 12:00 EST") }

  test "only admins see sign-ups" do
    WorkshopRsvp.sign_up(email: "guest@example.com", slot: "nov8")
    assert Admin::WorkshopRsvpPolicy.new(users(:admin), WorkshopRsvp).index?
    assert_not Admin::WorkshopRsvpPolicy.new(users(:member), WorkshopRsvp).index?
    assert_not Admin::WorkshopRsvpPolicy.new(nil, WorkshopRsvp).index?
    assert_equal 1, Admin::WorkshopRsvpPolicy::Scope.new(users(:admin), WorkshopRsvp).resolve.count
    assert_empty Admin::WorkshopRsvpPolicy::Scope.new(users(:member), WorkshopRsvp).resolve
  end
end
