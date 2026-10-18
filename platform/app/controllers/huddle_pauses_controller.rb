# Pause on the pet while in the huddle, choosing to stay but stop counting (HuddlePause), and Resume. Pausing
# also stops the site timer, since it means stop counting. Both are safe to press twice. Answers what the pet
# shows, like TimersController. Only ever the signed-in user's own.
class HuddlePausesController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; every action authorizes explicitly

  def create
    authorize current_user, :track_time?
    TimerSession.stop(current_user)
    HuddlePause.start(current_user)
    render_time
  end

  def destroy
    authorize current_user, :track_time?
    HuddlePause.finish(current_user.id, at: Time.current, reason: "resumed")
    render_time
  end

  private

  def render_time = render(json: TrackedTimeSerializer.render(TrackedTime.new(current_user), huddle: Huddle.current))
end
