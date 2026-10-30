require "test_helper"

class HuddleRingJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  CHANNEL = "CHUDDLE"
  LULU = "CLULU"
  SAMI = "CSAMI"

  test "rings someone into the main huddle" do
    browser = fake_browser { { "ok" => true } }
    ring(browser, users(:member))

    assert_equal [ [ "rooms.notifyMember", { channel_id: CHANNEL, user_id: "U0MEMBER", _x_reason: "huddle-notify-member" } ] ], browser.calls
  end

  test "a refused ring marks the main huddle full and rings them into their team's huddle instead" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, thread_ts: "1700000000.000100", started_at: 1.hour.ago)
    browser = fake_browser { |fields| fields[:channel_id] == CHANNEL ? SlackBot::BrowserClient::Error.new("rooms.notifyMember", "invite_failed") : { "ok" => true } }

    assert_enqueued_with(job: HuddleFullJob, args: [ huddle ]) do
      assert_enqueued_with(job: HuddleRingJob, args: [ users(:member), { retried: true } ]) { ring(browser, users(:member)) }
    end
    assert huddle.reload.full?

    ring(browser, users(:member), retried: true)
    assert_equal LULU, browser.calls.last.last[:channel_id]
  end

  test "a refused ring for someone already in the huddle does not mark it full" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.hour.ago)
    huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 10.minutes.ago)

    ring(fake_browser { SlackBot::BrowserClient::Error.new("rooms.notifyMember", "invite_failed") }, users(:member))

    assert_not huddle.reload.full?
  end

  test "each team goes to its own channel while the main huddle is full, everyone else to the main one" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.hour.ago)

    with_channels do
      assert_equal CHANNEL, Huddle.channel_for(users(:member), huddle)
      huddle.update!(full_at: Time.current)
      assert_equal [ LULU, SAMI, CHANNEL ], [ users(:member), users(:admin), users(:newcomer) ].map { |user| Huddle.channel_for(user, huddle) }
    end
  end

  private

  def ring(browser, *args, **options)
    SlackHuddle.instance_variable_set(:@client, browser)
    with_channels { HuddleRingJob.perform_now(*args, **options) }
  ensure
    SlackHuddle.reset!
  end

  def with_channels(&)
    with_env("SLACK_HUDDLE_CHANNEL_ID" => CHANNEL, "SLACK_HUDDLE_LULU_CHANNEL_ID" => LULU, "SLACK_HUDDLE_SAMI_CHANNEL_ID" => SAMI,
      "SLACK_BROWSER_TOKEN" => "xoxc-test", "SLACK_BROWSER_COOKIE" => "xoxd-test", &)
  end

  def fake_browser(&response) = FakeBrowserClient.new("rooms.notifyMember" => response)
end
