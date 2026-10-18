# Brings Huddle and HuddleSession rows in line with who Slack lists in the huddle. Runs whenever bin/slack-typing
# sees a huddle event and every minute (config/recurring.yml) for anything it missed. Someone new gets asked what
# they are working on (HuddlePromptJob); when a huddle ends and the bot starts the next one, the people who were
# still in the old one are asked to come over (HuddleHandoffJob).
class HuddleSyncJob < ApplicationJob
  queue_as :realtime
  # A Postgres lock rather than limits_concurrency: a worker killed mid-run (every deploy) drops it with its
  # connection, where a Solid Queue semaphore stays held until the dispatcher's next sweep, minutes later.
  LOCK = Zlib.crc32("huddle_sync")

  def perform
    return unless SlackHuddle.configured?

    connection = ActiveRecord::Base.connection
    connection.select_value("SELECT pg_advisory_lock(#{LOCK})")
    begin
      sync
    ensure
      connection.select_value("SELECT pg_advisory_unlock(#{LOCK})")
    end
  rescue ActiveRecord::QueryCanceled
    # Another sync held the lock past statement_timeout; the next event or the minute's run catches up.
    nil
  end

  private

  def sync
    huddle = Huddle.live.where(channel_id: SlackHuddle.channel_id).order(:started_at).last
    if huddle
      room = SlackHuddle.room(huddle.call_id)
      return seat(huddle, room) if room && !room.ended?

      huddle.end!(room&.ended_at || Time.current)
    end

    room = SlackHuddle.live_room or return
    huddle = Huddle.create_or_find_by!(call_id: room.call_id) do |new_huddle|
      new_huddle.assign_attributes(channel_id: SlackHuddle.channel_id, thread_ts: room.thread_ts, started_at: room.started_at)
    end
    return if huddle.ended?

    seat(huddle, room)
    hand_off(huddle)
  rescue SlackBot::BrowserClient::Error, Faraday::Error => e
    Rails.logger.error({ event: "huddle_sync.failed", error: e.message }.to_json)
  end

  def seat(huddle, room)
    # The bot is always in its own huddle, so an empty list means Slack did not say, not that everyone left.
    return if room.participant_ids.empty?

    present = room.participant_ids - [ SlackHuddle.user_id ]

    now = Time.current
    open = huddle.sessions.ongoing.index_by(&:slack_id)
    open.except(*present).each_value { |session| session.leave!(now) }

    arrived = present - open.keys
    return if arrived.empty?

    users = User.kept.where(slack_id: arrived).index_by(&:slack_id)
    earlier = huddle.sessions.where(slack_id: arrived).order(:joined_at).index_by(&:slack_id)
    arrived.each do |slack_id|
      before = earlier[slack_id]
      session = huddle.sessions.create!(slack_id: slack_id, user: users[slack_id], joined_at: now, mode: before&.mode, goal: before&.goal)
      HuddlePromptJob.perform_later(session) unless before
    end
  end

  def hand_off(huddle)
    previous = huddle.previous_for_handoff or return
    previous.update!(handed_off_at: Time.current)

    missing = previous.present_at_end - huddle.sessions.ongoing.pluck(:slack_id)
    HuddleHandoffJob.perform_later(huddle, missing) if missing.any?
  end
end
