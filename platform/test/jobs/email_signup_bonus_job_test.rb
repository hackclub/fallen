require "test_helper"

class EmailSignupBonusJobTest < ActiveJob::TestCase
  MESSAGE = "yoo, thanks for signing up from our email last weekend, here's the promised +20 XP :)"

  test "the bonus is DMed when it's paid, or when Slack is linked after" do
    from_email = { "utm_source" => XpEntry::EMAIL_SIGNUP_SOURCE }
    with_fake_slack do |slack|
      perform_enqueued_jobs(only: EmailSignupBonusJob) do
        travel_to(XpEntry::EMAIL_SIGNUP_UNTIL - 1.hour) do
          User.create!(email: "slack@example.com", display_name: "slack", roles: [ "user" ], slack_id: "U0EMAIL1", signup_source: from_email)
        end
      end
      assert_equal [ [ "U0EMAIL1", MESSAGE ] ], slack.calls_to(:chat_postMessage).map { [ it[:channel], it[:text] ] }

      user = travel_to(XpEntry::EMAIL_SIGNUP_UNTIL - 1.hour) { User.start_trial!(email: "later@example.com", signup_source: from_email) }
      perform_enqueued_jobs(only: EmailSignupBonusJob) do
        user.update!(slack_id: "U0EMAIL2")
        user.update!(display_name: "Later")
      end
      assert_equal [ "U0EMAIL1", "U0EMAIL2" ], slack.calls_to(:chat_postMessage).map { it[:channel] }
    end
  end
end
