# The pet's bubble after the site timer stops or hits its limit (TrackedTime#wrap_up): what they got done and how
# much of the counted time was really work (TimerSession#wrap_up!). There is no skip. Answers what the pet shows, like
# TimersController.
class TimerWrapUpsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #create authorizes explicitly

  def create
    authorize current_user, :track_time?
    time = TrackedTime.new(current_user)
    session = time.wrap_up
    return render(json: { error: "Say what you got done first" }, status: :unprocessable_content) if session && params[:done].blank?
    if session && !session.wrap_up!(done: params[:done], hours: params[:hours])
      return render(json: { error: session.errors.full_messages.to_sentence }, status: :unprocessable_content)
    end

    render json: TrackedTimeSerializer.render(TrackedTime.new(current_user), huddle: Huddle.current)
  end
end
