# The time someone has put in since their last journal, shown on the pet: their huddle sessions they were not
# just chilling in (HuddleSession#mode), less any time they paused (HuddlePause), and their site timer
# (TimerSession). Overlaps count once, so running the timer while in the huddle does not double it. Whatever they
# said was not really work when asked at the end (`deducted_seconds` on either) is cut from the end of that
# session's own time before overlaps are joined, so time that overlapped is never taken off twice. Only reads;
# nothing here changes a row.
class TrackedTime
  attr_reader :user, :now

  def initialize(user, now: Time.current)
    @user = user
    @now = now
  end

  # When the count starts: the newest journal, or the beginning for someone who has not written one.
  def since
    return @since if defined?(@since)

    @since = user.journals.kept.maximum(:created_at)
  end

  def seconds = self.class.total(huddle_stretches + timer_stretches)

  # What is going on now: "huddle" (in it and counting), "timer", "paused" (in the huddle, not counting) or nil.
  def running
    if counting_in_huddle? && !paused? then "huddle"
    elsif timer then "timer"
    elsif paused? then "paused"
    end
  end

  # In the huddle at all, even just chilling.
  def in_huddle? = open_sessions.any?

  # The site timer counting now, if any.
  def timer = timers.find { |session| session.stopped_at.nil? && session.counted_until(now) == now }

  # Their last site timer once it has stopped or hit its limit, until they say what they got done
  # (TimerSession#wrap_up!). Nil while one is counting.
  def wrap_up
    last = timers.max_by(&:started_at)
    last if last && last != timer && !last.wrapped_up_at && last.counted_seconds(now) >= TimerSession::WRAP_UP_MIN
  end

  # Seconds covered by `stretches`, overlaps once.
  def self.total(stretches) = union(stretches).sum { |from, to| to - from }.to_i

  # Overlapping stretches joined into one.
  def self.union(stretches)
    stretches.sort_by(&:first).each_with_object([]) do |(from, to), joined|
      if joined.any? && from <= joined.last[1]
        joined.last[1] = [ joined.last[1], to ].max
      else
        joined << [ from, to ]
      end
    end
  end

  # `stretches` (sorted, not overlapping) with `seconds` cut from the end.
  def self.trim(stretches, seconds)
    stretches.reverse.each_with_object([]) do |(from, to), kept|
      cut = [ seconds, to - from ].min
      seconds -= cut
      kept.unshift([ from, to - cut ]) if to - cut > from
    end
  end

  # `stretches` with the parts covered by `holes` (sorted, not overlapping) cut out.
  def self.subtract(stretches, holes)
    stretches.flat_map do |from, to|
      holes.each_with_object([ [ from, to ] ]) do |(hole_from, hole_to), pieces|
        next if pieces.empty?

        last_from, last_to = pieces.pop
        pieces << [ last_from, [ last_to, hole_from ].min ] if hole_from > last_from
        pieces << [ [ last_from, hole_to ].max, last_to ] if hole_to < last_to
      end.select { |a, b| b > a }
    end
  end

  private

  def counting_in_huddle? = open_sessions.any? { |session| session.mode != "chilling" }
  def paused? = in_huddle? && pauses.any? { |pause| pause.ended_at.nil? }

  # Every huddle session since `since`, chilling or not, in one query; open ones are always among them.
  def all_sessions
    @all_sessions ||= after_since(user.huddle_sessions, :left_at).to_a
  end

  def open_sessions = all_sessions.select { |session| session.left_at.nil? }
  def huddle_sessions = all_sessions.reject { |session| session.mode == "chilling" }

  def timers
    @timers ||= after_since(user.timer_sessions, :stopped_at).to_a
  end

  def pauses
    @pauses ||= after_since(user.huddle_pauses, :ended_at).to_a
  end

  def after_since(scope, end_column)
    since ? scope.where(end_column => nil).or(scope.where(end_column => since..)) : scope
  end

  def huddle_stretches
    holes = self.class.union(pauses.map { |pause| [ pause.started_at, pause.ended_at || now ] })
    clip(huddle_sessions.flat_map { |session| self.class.trim(self.class.subtract([ [ session.joined_at, session.left_at || now ] ], holes), session.deducted_seconds) })
  end

  def timer_stretches = clip(timers.flat_map { |session| self.class.trim([ [ session.started_at, session.counted_until(now) ] ], session.deducted_seconds) })

  # Each stretch cut to between `since` and now, dropping empty ones.
  def clip(stretches)
    stretches.map { |from, to| [ since ? [ from, since ].max : from, [ to, now ].min ] }.select { |from, to| to > from }
  end
end
