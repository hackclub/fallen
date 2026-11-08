require "test_helper"

# == Schema Information
#
# Table name: workshop_rsvps
#
#  id             :bigint           not null, primary key
#  email          :string           not null
#  slack_username :string
#  slot           :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_workshop_rsvps_on_email                (email) UNIQUE
#  index_workshop_rsvps_on_slot_and_created_at  (slot,created_at)
#
class WorkshopRsvpTest < ActiveSupport::TestCase
  setup { travel_to Time.zone.parse("2026-11-04 12:00 EST") }

  test "signing up again with the same email moves the person" do
    WorkshopRsvp.sign_up(email: " Guest@Example.com ", slack_username: "@guest", slot: "nov8")
    rsvp = WorkshopRsvp.sign_up(email: "guest@example.com", slot: "nov11")

    assert_equal 1, WorkshopRsvp.count
    assert_equal "nov11", rsvp.slot
    assert_nil rsvp.slack_username
  end

  test "keeps the Slack name without its @" do
    assert_equal "guest", WorkshopRsvp.sign_up(email: "guest@example.com", slack_username: " @guest ", slot: "nov8").slack_username
  end

  test "needs an email and one of the times" do
    rsvp = WorkshopRsvp.sign_up(email: "nope", slot: "midnight")
    assert rsvp.errors.of_kind?(:email, :invalid)
    assert rsvp.errors.of_kind?(:slot, :inclusion)
    assert_equal 0, WorkshopRsvp.count
  end

  test "the sessions are 2pm and 6pm Eastern" do
    assert_equal [ 14, 18 ], WorkshopRsvp.slots.map { it[:starts_at].in_time_zone("America/New_York").hour }
  end

  test "a session that has started is hidden and takes no more sign-ups" do
    travel_to WorkshopRsvp::SLOTS["nov8"].first
    assert_equal %w[nov11], WorkshopRsvp.upcoming_slots.pluck(:key)
    assert WorkshopRsvp.sign_up(email: "late@example.com", slot: "nov8").errors.of_kind?(:slot, :started)
    assert WorkshopRsvp.sign_up(email: "late@example.com", slot: "nov11").persisted?
  end
end
