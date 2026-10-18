# The pet's timer (components/PetTimer.svelte): the time put in since the last journal, and the site's own timer
# for anyone who would rather not join the huddle. Answers JSON, since the pet asks for it on every page and
# keeping it out of the shared props keeps it off every request. Only ever the signed-in user's own.
class TimersController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; every action authorizes explicitly

  def show
    authorize current_user, :show?
    render_time
  end

  def create
    authorize current_user, :track_time?
    TimerSession.start(current_user)
    render_time
  end

  def destroy
    authorize current_user, :track_time?
    TimerSession.stop(current_user)
    render_time
  end

  private

  def render_time = render(json: TrackedTimeSerializer.render(TrackedTime.new(current_user), huddle: Huddle.current))
end
