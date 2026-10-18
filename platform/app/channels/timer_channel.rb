# Tells someone's open pages that their pet's timer changed (lib/timer.svelte.ts), so joining the huddle or
# writing a journal shows on the pet within a second. Carries no data: the page asks TimersController for the
# time, so there is one answer and nothing to get out of step.
class TimerChannel < ApplicationCable::Channel
  def subscribed = stream_for(current_user)

  def self.changed(user_or_id)
    return if user_or_id.nil?

    user = user_or_id.is_a?(User) ? user_or_id : User.new(id: user_or_id)
    broadcast_to(user, { changed: true })
  end
end
