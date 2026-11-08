require "test_helper"

class DayEndReminderPingJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  EVENING = Time.utc(2026, 11, 5, 20, 0)

  setup do
    @member = users(:member)
    @teammate = users(:newcomer)
    @teammate.update_columns(pet: "lulu", slack_id: "U0NEWCOMER")
    XpEntry.where(user: [ @member, @teammate ]).update_all(day: Date.new(2026, 1, 1))
    [ @member, @teammate ].each { DayEndReminder.create!(user: it) }
  end

  test "the ping remembers its message, and has no buttons" do
    with_ping do |_slack, ping|
      assert_equal [ "CLULU", ping[:ts] ], @member.day_end_reminder.reload.values_at(:ping_channel_id, :ping_ts)
      assert_equal 1, ping[:blocks].size
    end
  end

  test "journaling crosses them off, and deleting the journal puts them back" do
    with_ping do |slack, ping|
      entry = nil
      assert_enqueued_with(job: DayEndReminderPingJob, args: [ "CLULU", ping[:ts] ]) do
        entry = @member.xp_entries.create!(kind: "journal", day: Date.new(2026, 11, 5), amount: 5)
      end
      travel_to(EVENING + 30.minutes) { perform_enqueued_jobs }
      update = slack.calls_to(:chat_update).last
      assert_equal [ "CLULU", ping[:ts] ], update.values_at(:channel, :ts)
      assert_equal "~<@U0MEMBER>~ :check-fallen: <@U0NEWCOMER> About 3.5 hours left in your day and no journal yet :hm:  YOU GOT THIS!! :lulu-boba:", update[:text]
      assert_nil update[:username], "chat.update keeps the pet it was posted as"

      entry.discard
      travel_to(EVENING + 40.minutes) { perform_enqueued_jobs }
      assert_match "<@U0MEMBER> <@U0NEWCOMER> About", slack.calls_to(:chat_update).last[:text]
    end
  end

  test "once everyone has journaled it says so" do
    with_ping do |slack, ping|
      [ @member, @teammate ].each { it.xp_entries.create!(kind: "journal", day: Date.new(2026, 11, 5), amount: 5) }
      travel_to(EVENING + 1.hour) { perform_enqueued_jobs }
      update = slack.calls_to(:chat_update).last
      assert_equal "~<@U0MEMBER>~ ~<@U0NEWCOMER>~ :check-fallen: Everyone here journaled tonight. LET'S GO!! :fallen-star: :lulu-boba:", update[:text]
    end
  end

  test "redrawn after their day is over, the ones left get a goodnight" do
    with_ping do |slack, ping|
      travel_to(Time.utc(2026, 11, 6, 0, 30)) { DayEndReminderPingJob.perform_now("CLULU", ping[:ts]) }
      update = slack.calls_to(:chat_update).last
      assert_equal "<@U0MEMBER> <@U0NEWCOMER> That's the end of the day! See you tomorrow :lulu-boba:", update[:text]
    end
  end

  test "a Slack failure redrawing is reported, not raised" do
    with_ping do |slack, ping|
      slack.define_singleton_method(:chat_update) { |**| raise Slack::Web::Api::Errors::SlackError, "message_not_found" }
      assert_error_reported(Slack::Web::Api::Errors::SlackError) do
        travel_to(EVENING + 1.hour) { DayEndReminderPingJob.perform_now("CLULU", ping[:ts]) }
      end
    end
  end

  private

  # Runs the evening's ping for the member and teammate, both Team Lulu, and yields the fake Slack and the post.
  def with_ping
    with_fake_slack do |slack|
      with_env("SLACK_LULU_CHANNEL_ID" => "CLULU") do
        travel_to(EVENING) { DayEndReminderJob.perform_now }
        posted = slack.calls_to(:chat_postMessage).sole
        yield slack, posted.merge(ts: @member.day_end_reminder.reload.ping_ts)
      end
    end
  end
end
