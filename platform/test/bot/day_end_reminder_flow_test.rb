require "test_helper"

class DayEndReminderFlowTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "opting in and out from the announcement answers only the person who pressed" do
    with_fake_slack do |slack|
      press("on")
      assert DayEndReminder.exists?(user: users(:member))
      press("on")
      assert_equal 1, DayEndReminder.where(user: users(:member)).count, "pressing twice keeps one"
      joined = slack.calls_to(:chat_postEphemeral).first
      assert_match "Let's go! I'll ping you in your team's channel when there are 4 hours left", joined[:text]
      assert_equal [ "Lulu", SlackMessages::PET_PFPS["lulu"] ], joined.values_at(:username, :icon_url), "from their own pet"

      press("off")
      assert_not DayEndReminder.exists?(user: users(:member))
      assert_equal [ "CLULU", "U0MEMBER" ], slack.calls_to(:chat_postEphemeral).last.values_at(:channel, :user)
      assert_empty slack.calls_to(:chat_postMessage)
    end
  end

  test "someone who hasn't picked a pet is kept, and told pings start once they have" do
    users(:newcomer).update_columns(slack_id: "U0NEWCOMER")
    with_fake_slack do |slack|
      press("on", user: "U0NEWCOMER")
      assert DayEndReminder.exists?(user: users(:newcomer))
      reply = slack.calls_to(:chat_postEphemeral).sole
      assert_match "once you've finished signing up on Fallen and picked your pet", reply[:text]
      assert_nil reply[:username], "no pet yet, so the bot answers"
    end
  end

  test "someone whose Slack isn't linked to Fallen is told how to link it" do
    with_fake_slack do |slack|
      press("on", user: "U0STRANGER")
      assert_equal 0, DayEndReminder.count
      reply = slack.calls_to(:chat_postEphemeral).sole[:text]
      assert_match "I couldn't find a Fallen account linked to your Slack", reply
      assert_match "/auth/slack/start", reply
    end
  end

  test "JOIN on the test copy of the announcement pings them in that channel right away; on the real one it waits" do
    with_fake_slack do
      assert_enqueued_with(job: DayEndReminderPreviewJob, args: [ "CTEST", [ "U0MEMBER" ] ]) do
        press("on", value: SlackMessages::DAY_END_PREVIEW, channel: "CTEST")
      end
      assert_no_enqueued_jobs(only: DayEndReminderPreviewJob) { press("on", channel: "CBULLETIN") }
    end
  end

  test "only the test copy of the announcement marks its JOIN" do
    real, test = [ false, true ].map { SlackMessages.day_end_reminder_announcement(preview: it)[:blocks].last[:elements].first[:value] }
    assert_nil real
    assert_equal SlackMessages::DAY_END_PREVIEW, test
  end

  private

  def press(choice, user: "U0MEMBER", ts: nil, value: nil, channel: "CLULU")
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => user }, "channel" => { "id" => channel }, "trigger_id" => "t",
                                    "response_url" => "https://hooks.slack.test/r", "message" => ({ "ts" => ts } if ts),
                                    "actions" => [ { "action_id" => "day_end_reminder:#{choice}", "value" => value }.compact ] }.compact)
  end
end
