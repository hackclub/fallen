# What the pet's timer shows (TimersController, HuddlePausesController): the time since the last journal, what is
# counting it now (TrackedTime#running), whether they are in the huddle at all, and where the huddle is for the
# "Join the huddle?" prompt.
class TrackedTimeSerializer < ApplicationSerializer
  typelize seconds: :number, running: [ :string, nullable: true ], in_huddle: :boolean, huddle_url: [ :string, nullable: true ], can_ring: :boolean
  attributes :seconds, :running
  attribute(:in_huddle, &:in_huddle?)
  attribute(:huddle_url) { |_| params[:huddle]&.join_url }
  attribute(:can_ring) { |time| SlackHuddle.configured? && time.user.slack_id.present? }
end
