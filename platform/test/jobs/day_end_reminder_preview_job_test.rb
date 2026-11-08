require "test_helper"

class DayEndReminderPreviewJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @member = users(:member)
    DayEndReminder.create!(user: @member)
    DayEndReminder.create!(user: users(:admin))
  end

  test "pings only the people named, right away, into the channel given, as if it were 8pm" do
    @member.xp_entries.journals.first.update_columns(day: Date.new(2026, 11, 5))
    with_fake_slack do |slack|
      travel_to(Time.utc(2026, 11, 5, 9, 0)) { DayEndReminderPreviewJob.perform_now("CTEST", [ "U0MEMBER" ]) }
      ping = slack.calls_to(:chat_postMessage).sole
      assert_equal [ "CTEST", "Lulu" ], ping.values_at(:channel, :username)
      assert_equal "<@U0MEMBER> About 4 hours left in your day and no journal yet :hm:  YOU GOT THIS!! :lulu-boba:", ping[:text]

      reminder = @member.day_end_reminder.reload
      assert_equal [ Date.new(2026, 11, 5), "CTEST" ], reminder.values_at(:reminded_on, :ping_channel_id), "a real ping, so journaling crosses them off"
      assert_nil users(:admin).day_end_reminder.reload.reminded_on, "nobody else is touched"
    end
  end

  test "someone who didn't opt in isn't pinged" do
    with_fake_slack do |slack|
      DayEndReminderPreviewJob.perform_now("CTEST", [ "U0NOBODY" ])
      assert_empty slack.calls_to(:chat_postMessage)
    end
  end
end
