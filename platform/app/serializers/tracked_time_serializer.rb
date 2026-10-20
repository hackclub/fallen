# What the pet's timer shows (TimersController, HuddlePausesController): the time since the last journal, what is
# counting it now (TrackedTime#running), whether they are in the huddle at all, and where the huddle is for the
# "Join the huddle?" prompt. `wrap_up` is their stopped site timer waiting to be asked what they got done
# (TrackedTime#wrap_up), with what it counted as `hours` the way the answer is typed. `check_in` is the hourly
# check-in waiting for an answer (TrackedTime#check_in), `so_far` the time it was sent at ("2 hours").
class TrackedTimeSerializer < ApplicationSerializer
  typelize seconds: :number, running: [ :string, nullable: true ], in_huddle: :boolean, huddle_url: [ :string, nullable: true ], can_ring: :boolean,
    wrap_up: [ "{ goal: string | null; hours: string }", nullable: true ], max_hours: :number,
    check_in: [ "{ id: string; so_far: string }", nullable: true ]
  attributes :seconds, :running
  attribute(:wrap_up) { |time| time.wrap_up&.then { |session| { goal: session.goal, hours: HonestHours.text(session.counted_seconds(time.now)) } } }
  attribute(:check_in) { |time| time.check_in&.then { |check_in| { id: check_in.public_id, so_far: SlackMessages.duration_words(check_in.minutes) } } }
  attribute(:max_hours) { |_| TimerSession::MAX_LENGTH.in_hours.to_i }
  attribute(:in_huddle, &:in_huddle?)
  attribute(:huddle_url) { |_| params[:huddle]&.join_url || SlackHuddle.huddle_url }
  # The ring itself happens on the worker (HuddleRingJob), which holds the huddle account's session; the web
  # only needs to know there is a huddle channel.
  attribute(:can_ring) { |time| SlackHuddle.channel_id.present? && time.user.slack_id.present? }
end
