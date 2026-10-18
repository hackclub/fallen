# frozen_string_literal: true

# The huddle the user bot sits in around the clock, in SLACK_HUDDLE_CHANNEL_ID. Huddles have no public API, so
# this uses the account's browser session (SLACK_BROWSER_TOKEN and SLACK_BROWSER_COOKIE, the same ones
# bin/slack-typing uses) the way Slack's desktop client does. The method shapes follow
# https://github.com/ingoau/huddlefm. KeepHuddleJob does the joining and rejoining.
module SlackHuddle
  Room = Data.define(:call_id, :thread_ts, :participant_ids, :ended) do
    def active? = !ended
    def includes?(user_id) = participant_ids.include?(user_id)
  end

  # Where Slack's media servers should host the huddle; the bot never connects to them.
  REGION = "us-east-1"

  module_function

  def channel_id = ENV["SLACK_HUDDLE_CHANNEL_ID"].presence

  def configured? = channel_id.present? && ENV["SLACK_BROWSER_TOKEN"].present? && ENV["SLACK_BROWSER_COOKIE"].present?

  # Joins the channel's huddle, starting one when none is running.
  def join
    body = client.call("rooms.join", channel_id: channel_id, regions: REGION, multidevice: "true")
    huddle = body.fetch("huddle")
    Room.new(
      call_id: body.fetch("call").fetch("call_id"),
      thread_ts: body.dig("canvas", "root_thread_ts"),
      participant_ids: participant_ids(huddle["participants"]),
      ended: huddle["has_ended"] == true || huddle["date_end"].to_i.positive?
    )
  end

  # The huddle as Slack sees it now, or nil when Slack no longer knows it.
  def room(call_id)
    body = client.call("screenhero.rooms.info", room: call_id, _x_reason: "all-calls-store/conditional-fetch")
    room = body.fetch("room")
    Room.new(
      call_id: room.fetch("id"),
      thread_ts: room["thread_root_ts"] || room["canvas_thread_ts"],
      participant_ids: participant_ids(room["participants"]),
      ended: room["has_ended"] == true || room["date_end"].to_i.positive?
    )
  rescue SlackBot::BrowserClient::Error => e
    raise unless e.code.start_with?("rooms_")

    nil
  end

  # The Slack user id of the account behind the browser session.
  def user_id
    @user_id ||= client.call("auth.test").fetch("user_id")
  end

  # True for a real-time event (SlackBot::BrowserSocket) saying the huddle with this call id ended or that the
  # user bot left it, so KeepHuddleJob can rejoin straight away rather than on its next scheduled run.
  def left?(event, call_id)
    return false unless call_id

    case event["type"]
    when "sh_room_update"
      huddle = event["huddle"] || {}
      ids = [ event.dig("room", "call_id"), huddle["id"] ]
      ids.include?(call_id) && (huddle["has_ended"] == true || huddle["date_end"].to_i.positive?)
    when "sh_room_leave"
      ids = [ event["call_id"], event.dig("room", "call_id"), event.dig("room", "id"), event.dig("huddle", "id") ]
      ids.include?(call_id) && event["user"] == user_id
    else
      false
    end
  end

  def client
    @client ||= SlackBot::BrowserClient.new(token: ENV.fetch("SLACK_BROWSER_TOKEN"), cookie: ENV.fetch("SLACK_BROWSER_COOKIE"))
  end

  def reset! = @client = @user_id = nil

  # Slack lists participants as user ids or as membership objects.
  def participant_ids(list)
    Array(list).filter_map { |entry| entry.is_a?(Hash) ? entry["user_id"] : entry }
  end
end
