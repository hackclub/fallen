# frozen_string_literal: true

# The huddle the user bot keeps open in SLACK_HUDDLE_CHANNEL_ID (script/slack_huddle.mjs), read the way Slack's
# own client reads it. Huddles have no public API, so this uses the account's browser session
# (SLACK_BROWSER_TOKEN and SLACK_BROWSER_COOKIE). HuddleSyncJob and HuddleHandoffJob use it.
#
# Slack lets a huddle take 250 joins, rejoins included, so a busy day fills it. Each team then gets a huddle of its
# own in its channel (SLACK_HUDDLE_LULU_CHANNEL_ID, SLACK_HUDDLE_SAMI_CHANNEL_ID) until the main one restarts.
module SlackHuddle
  Room = Data.define(:call_id, :thread_ts, :link, :participant_ids, :screenshare_ids, :camera_ids, :started_at, :ended_at) do
    def ended? = !ended_at.nil?
  end

  # How far back to look for the huddle's message in the channel. Slack ends huddles after 24 hours.
  LOOKBACK = 25.hours
  # The team channels the account should keep a huddle open in besides the main one, one per line, written by
  # HuddleSyncJob and read by script/slack_huddle.mjs, which run in the same container.
  OVERFLOW_FILE = Rails.root.join("tmp/huddle_overflow")

  module_function

  def channel_id = ENV["SLACK_HUDDLE_CHANNEL_ID"].presence

  def configured? = channel_id.present? && ENV["SLACK_BROWSER_TOKEN"].present? && ENV["SLACK_BROWSER_COOKIE"].present?

  # Where a team goes when the main huddle is full, or nil when that team has no channel set up.
  def team_channel_id(pet) = pet.present? ? ENV["SLACK_HUDDLE_#{pet.upcase}_CHANNEL_ID"].presence : nil

  def team_channel_ids = Team::BY_PET.keys.filter_map { |pet| team_channel_id(pet) }

  def channel_ids = [ channel_id, *team_channel_ids ].compact

  # Asks script/slack_huddle.mjs to keep the account in a huddle in these team channels too.
  def overflow!(channel_ids)
    text = channel_ids.map { |id| "#{id}\n" }.join
    return if OVERFLOW_FILE.exist? && OVERFLOW_FILE.read == text

    OVERFLOW_FILE.dirname.mkpath
    temp = "#{OVERFLOW_FILE}.#{Process.pid}"
    File.write(temp, text)
    File.rename(temp, OVERFLOW_FILE)
  end

  # Opens the channel's huddle in Slack. Not the app.slack.com link Slack shares (Room#link): that one redirects to
  # slack.com/huddle/C… and loses the workspace on the way, see SlackMessaging::WORKSPACE_URL.
  def huddle_url(channel_id = self.channel_id)
    "#{SlackMessaging::WORKSPACE_URL}/huddle/#{channel_id}" if channel_id
  end

  # The huddle running in the channel now, found from the message Slack posts when one starts. Nil when none is.
  def live_room(channel = channel_id)
    body = client.call("conversations.history", channel: channel, oldest: LOOKBACK.ago.to_i, limit: 200)
    message = Array(body["messages"]).find { |m| m["subtype"] == "huddle_thread" && m["room"].is_a?(Hash) }
    return unless message

    room = parse(message["room"], thread_ts: message["ts"])
    room unless room.ended?
  end

  # The huddle as Slack sees it now, or nil when Slack no longer knows it.
  def room(call_id)
    parse(client.call("screenhero.rooms.info", room: call_id, _x_reason: "all-calls-store/conditional-fetch").fetch("room"))
  rescue SlackBot::BrowserClient::Error => e
    raise unless e.code.start_with?("rooms_")

    nil
  end

  # Rings someone into the channel's huddle, like "Invite to huddle" in Slack's client. Slack answers
  # `invite_failed` once the huddle is full.
  def ring(slack_id, channel = channel_id)
    client.call("rooms.notifyMember", channel_id: channel, user_id: slack_id, _x_reason: "huddle-notify-member")
  end

  # The Slack user id of the account behind the browser session, which sits in the huddle around the clock.
  def user_id
    @user_id ||= client.call("auth.test").fetch("user_id")
  end

  def client
    @client ||= SlackBot::BrowserClient.new(token: ENV.fetch("SLACK_BROWSER_TOKEN"), cookie: ENV.fetch("SLACK_BROWSER_COOKIE"))
  end

  def reset! = @client = @user_id = nil

  def parse(room, thread_ts: nil)
    ended = room["date_end"].to_i.positive? ? Time.zone.at(room["date_end"].to_i) : (Time.current if room["has_ended"] == true)
    Room.new(
      call_id: room.fetch("id"),
      thread_ts: thread_ts || room["thread_root_ts"] || room["canvas_thread_ts"],
      link: room["huddle_link"].presence,
      participant_ids: user_ids(room["participants"]),
      screenshare_ids: user_ids(room["participants_screenshare_on"]),
      camera_ids: user_ids(room["participants_camera_on"]),
      started_at: room["date_start"].to_i.positive? ? Time.zone.at(room["date_start"].to_i) : Time.current,
      ended_at: ended
    )
  end

  # Slack lists people as user ids or as membership objects.
  def user_ids(list) = Array(list).filter_map { |entry| entry.is_a?(Hash) ? entry["user_id"] : entry }
end
