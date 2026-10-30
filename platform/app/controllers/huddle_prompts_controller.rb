# Start on the pet while just chilling in the huddle: their time counts again and Slack asks what they are working
# on (HuddleSession#ask_again!). Answers what the pet shows, like TimersController.
class HuddlePromptsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #create authorizes explicitly
  rate_limit to: 5, within: 1.minute, only: :create, by: -> { current_user.id }, with: -> { head :too_many_requests }

  def create
    authorize current_user, :track_time?
    current_user.huddle_sessions.ongoing.joins(:huddle).merge(Huddle.live).order(:joined_at).last&.ask_again!
    render json: TrackedTimeSerializer.render(TrackedTime.new(current_user), huddle: Huddle.current)
  end
end
