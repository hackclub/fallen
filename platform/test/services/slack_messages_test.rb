require "test_helper"

class SlackMessagesTest < ActiveSupport::TestCase
  PINGS = [ "<!channel>", "<!here>", "<!everyone>", "<@U123>", "<!subteam^S123>", "<#C123>" ].freeze
  # What Slack would read as a mention: a bracketed one, or a bare broadcast word.
  MENTION = /<[!@#]|@(channel|here|everyone)\b/i

  test "a project's title and description can't ping anyone" do
    project = projects(:station)
    project.title = "<!channel> @here"
    project.description = PINGS.join(" ") + " @everyone @Channel"

    anchor = SlackMessages.project_anchor(project)
    assert_no_match MENTION, anchor[:text]
    assert_no_match MENTION, anchor[:blocks].to_json
  end

  test "a name stood in for a missing Slack id can't ping anyone" do
    user = users(:member)
    user.slack_id = nil
    user.display_name = "<!channel> @here"

    message = SlackMessages.teammate_joined(projects(:station), user)
    assert_no_match MENTION, message[:text]
    assert_no_match MENTION, message[:blocks].to_json
  end

  test "Markdown links only become Slack links for web addresses" do
    text = SlackMessages.mrkdwn("[hi](!channel) [x](@U123) ![y](!subteam^S1) [ok](https://fallen.hackclub.com)")

    assert_no_match MENTION, text
    assert_includes text, "<https://fallen.hackclub.com|ok>"
  end

  test "journal review feedback is Markdown, in Slack's own formatting, and still can't ping" do
    review = ProgressReview.new(project: projects(:station), verdict: "approved",
      feedback: "**Great** wiring, *keep* it up\n- [How to journal](https://example.com/docs)\n- <!channel> @here")

    text = SlackMessages.progress_reviewed(review)[:text]
    assert text.start_with?("Journal review:\n*Great* wiring, _keep_ it up\n• <https://example.com/docs|How to journal>"), text
    assert_no_match MENTION, text
  end

  test "what Markdown escaped reaches Slack as written, unformatted" do
    assert_equal "snake_case 2*3 *bold* [not a link]", SlackMessages.mrkdwn("snake\\_case 2\\*3 **bold** \\[not a link\\]")
  end

  test "nested Markdown lists stay nested in Slack" do
    text = SlackMessages.mrkdwn("- Wiring\n  - Add a photo\n    - Of the back\n1. First\n2) Second")
    assert_equal "• Wiring\n\u2003◦ Add a photo\n\u2003\u2003▪ Of the back\n1. First\n2. Second", text
  end

  test "text Slack handed over loses its broadcasts and group pings" do
    text = SlackMessages.quote("look <!channel> <!here|here> <!subteam^S1|@devs> @everyone", 100)

    assert_no_match MENTION, text
    assert_includes text, "@devs"
  end
end
