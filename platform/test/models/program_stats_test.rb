require "test_helper"

class ProgramStatsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    travel_to Time.utc(2026, 10, 21, 12)
    @huddle = Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", started_at: 3.days.ago)
  end

  teardown { travel_back }

  test "days end at midnight in New York, so the evening there is not tomorrow yet" do
    travel_to Time.utc(2026, 10, 22, 2)
    assert_equal "2026-10-21", ProgramStats.new(range: "7d").daily[:days].last[:date]
  end

  test "tracked time is everyone's huddle and timer time by New York day, overlaps once, never chilling" do
    member, admin = users(:member), users(:admin)
    # Across New York's midnight (4am UTC): 1 hour on the 20th, 2 on the 21st, half an hour of it paused.
    session(member, joined_at: Time.utc(2026, 10, 21, 3), left_at: Time.utc(2026, 10, 21, 6))
    member.huddle_pauses.create!(started_at: Time.utc(2026, 10, 21, 5), ended_at: Time.utc(2026, 10, 21, 5, 30))
    # The timer overlaps the huddle for half an hour, so adds only half an hour.
    member.timer_sessions.create!(started_at: Time.utc(2026, 10, 21, 5, 30), stopped_at: Time.utc(2026, 10, 21, 6, 30))
    session(admin, joined_at: Time.utc(2026, 10, 21, 7), left_at: Time.utc(2026, 10, 21, 9), mode: "chilling")
    # Before the range.
    admin.timer_sessions.create!(started_at: 40.days.ago, stopped_at: 40.days.ago + 1.hour)

    daily = ProgramStats.new(range: "7d").daily
    days = daily[:days].index_by { it[:date] }

    assert_equal 7, daily[:days].size
    assert_equal 60, days["2026-10-20"][:tracked_minutes]
    assert_equal 120, days["2026-10-21"][:tracked_minutes]
    assert_equal 180, daily[:totals][:tracked_minutes]
    assert_equal 1, days["2026-10-20"][:builders]
    assert_equal 1, daily[:totals][:builders], "the member journaled today too, and counts once"
    assert_equal 150, daily[:totals][:logged_minutes]
  end

  test "active counts builders by when they last tracked time or journaled, and visitors by day" do
    Journal.update_all(created_at: 40.days.ago)
    users(:member).journals.first.update_columns(created_at: 2.hours.ago)
    users(:admin).timer_sessions.create!(started_at: 3.days.ago, stopped_at: 3.days.ago + 1.hour)
    users(:newcomer).touch_last_seen
    session(users(:admin), joined_at: 2.hours.ago, left_at: 1.hour.ago, mode: "chilling")

    assert_equal({ day: 1, week: 2, month: 2 }, ProgramStats.new(range: "30d").active, "visiting or chilling isn't building")
    assert_equal 1, ProgramStats.new(range: "7d").daily[:days].last[:visitors]
  end

  test "each funnel step counts people who made it and every step before" do
    User.update_all(created_at: 1.day.ago, last_seen_at: 1.day.ago)
    users(:newcomer).update_columns(pet: "lulu")

    counts = ProgramStats.new(range: "7d").funnel.to_h { [ it[:key], it[:count] ] }

    assert_equal 3, counts["signed_up"], "banned accounts are left out"
    assert_equal 3, counts["picked_pet"]
    # Only the member connected Slack; the admin never did, so stops there with the newcomer.
    assert_equal 1, counts["slack"]
    assert_equal 1, counts["project"]
    assert_equal 0, counts["tracked"]
    assert_equal 0, counts["returned"]
  end

  test "sources group signups by UTM source, then ref, then referring site, and sum the small ones" do
    User.update_all(created_at: 1.day.ago, signup_source: {})
    users(:member).update_columns(signup_source: { "utm_source" => "bigemailthing", "ref" => "slack-join" })
    users(:admin).update_columns(signup_source: { "referrer" => "https://chatgpt.com/c/abc" })
    ProgramStats::SOURCE_MIN_SIGNUPS.times { User.start_trial!(email: "ref#{it}@example.com", signup_source: { "ref" => "fallout-link" }) }

    assert_equal [ { source: "fallout-link", signups: 5, builders: 0 }, { source: "", signups: 1, builders: 0 }, { source: nil, signups: 2, builders: 1 } ],
      ProgramStats.new(range: "7d").sources, "banned accounts are left out; the member journaled"
  end

  private

  def session(user, mode: nil, **times)
    @huddle.sessions.create!(user: user, slack_id: user.slack_id, mode: mode, **times)
  end
end
