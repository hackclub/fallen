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

  test "Markdown links only become Slack links for web addresses" do
    text = SlackMessages.mrkdwn("[hi](!channel) [x](@U123) ![y](!subteam^S1) [ok](https://fallen.hackclub.com)")

    assert_no_match MENTION, text
    assert_includes text, "<https://fallen.hackclub.com|ok>"
  end

  test "text Slack handed over loses its broadcasts and group pings" do
    text = SlackMessages.quote("look <!channel> <!here|here> <!subteam^S1|@devs> @everyone", 100)

    assert_no_match MENTION, text
    assert_includes text, "@devs"
  end
end
