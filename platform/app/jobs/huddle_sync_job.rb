# Brings Huddle and HuddleSession rows in line with who Slack lists in the huddle. Runs whenever bin/slack-typing
# sees a huddle event and every minute (config/recurring.yml) for anything it missed. Someone new gets asked what
# they are working on, in the thread and in a DM (HuddlePromptJob), and someone leaving what they got done
# (HuddleWrapUpJob); when a huddle ends and the bot starts the next one, the people who were still in the old one
# are asked to come over (HuddleHandoffJob).
class HuddleSyncJob < ApplicationJob
  queue_as :realtime
  # A Postgres lock rather than limits_concurrency: a worker killed mid-run (every deploy) drops it with its
  # connection, where a Solid Queue semaphore stays held until the dispatcher's next sweep, minutes later.
  LOCK = Zlib.crc32("huddle_sync")

  def perform
    return unless SlackHuddle.configured?

    connection = ActiveRecord::Base.connection
    connection.execute("SELECT pg_advisory_lock(#{LOCK})")
    begin
      sync
    ensure
      connection.execute("SELECT pg_advisory_unlock(#{LOCK})")
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
      if room && !room.ended?
        huddle.update!(link: room.link) if room.link && huddle.link != room.link
        return seat(huddle, room)
      end

      huddle.end!(room&.ended_at || Time.current)
    end

    room = SlackHuddle.live_room or return
    huddle = Huddle.create_or_find_by!(call_id: room.call_id) do |new_huddle|
      new_huddle.assign_attributes(channel_id: SlackHuddle.channel_id, thread_ts: room.thread_ts, link: room.link, started_at: room.started_at)
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
    open.except(*present).each_value do |session|
      left_at, source = huddle.departure(session, now)
      session.leave!(left_at, source)
      HuddlePause.finish(session.user_id, at: left_at, reason: "left") if session.user_id
    end
    staying = open.slice(*present).values
    HuddleSession.where(id: staying.map(&:id)).update_all(last_seen_at: now)
    staying.each { |session| session.sharing!(now, screen: room.screenshare_ids.include?(session.slack_id), camera: room.camera_ids.include?(session.slack_id)) }

    arrived = present - open.keys
    welcome(huddle, room, arrived, now) if arrived.any?
    # A pause can only last while its person is in the huddle; this also ends one that raced a leave.
    HuddlePause.finish(HuddlePause.open.where.not(user_id: HuddleSession.ongoing.where.not(user_id: nil).select(:user_id)).pluck(:user_id), at: now, reason: "left")
  end

  def welcome(huddle, room, arrived, now)
    users = User.kept.where(slack_id: arrived).index_by(&:slack_id)
    earlier = huddle.sessions.where(slack_id: arrived).order(:joined_at).index_by(&:slack_id)
    carried = huddle.carried_over(arrived - earlier.keys, at: now)
    arrived.each { |slack_id| arrive(huddle, room, slack_id, users[slack_id], earlier[slack_id], carried[slack_id], now) }
  end

  # Everyone is asked on every visit; someone who was working on something is asked whether they still are. A
  # dropped connection, or coming over from the last huddle when Slack restarted it, keeps an answer instead. With
  # no answer yet they are asked again, since the private prompt goes away when they leave. Someone who said they
  # were just chilling stays chilling for the rest of the huddle without being asked again; the prompt in their DMs
  # still works if they start on something.
  def arrive(huddle, room, slack_id, user, earlier, carried, now)
    joined_at, source = huddle.arrival(slack_id, after: earlier&.left_at || huddle.started_at, now: now)
    kept = earlier if earlier&.mode == "chilling" || (earlier&.mode && earlier.left_at > joined_at - Huddle::REJOIN_QUIET)
    kept ||= carried if carried&.mode
    attributes = if kept
      { mode: kept.mode, goal: kept.goal, prompted_at_count: kept.prompted_at_count }
    else
      { goal: (earlier || carried)&.goal, prompted_at_count: huddle.message_count }
    end

    resume_pause(user, earlier, joined_at) if user && earlier
    session = huddle.sessions.create!(
      slack_id: slack_id, user: user, joined_at: joined_at, join_source: source, last_seen_at: now,
      screenshare_since: (now if room.screenshare_ids.include?(slack_id)), camera_since: (now if room.camera_ids.include?(slack_id)),
      **attributes
    )
    HuddlePromptJob.perform_later(session, dm: true) unless kept
  end

  # Someone who paused and dropped out for a moment is still paused when they come straight back.
  def resume_pause(user, earlier, joined_at)
    return unless earlier.left_at > joined_at - Huddle::REJOIN_QUIET
    return unless HuddlePause.exists?(user: user, end_reason: "left", ended_at: earlier.left_at)

    HuddlePause.create!(user: user, started_at: joined_at)
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def hand_off(huddle)
    previous = huddle.previous
    return if previous.nil? || previous.handed_off_at
    previous.update!(handed_off_at: Time.current)

    missing = previous.present_at_end - huddle.sessions.ongoing.pluck(:slack_id)
    HuddleHandoffJob.perform_later(huddle, missing) if missing.any?
  end
end
