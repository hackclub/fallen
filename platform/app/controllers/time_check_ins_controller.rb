# The pet's check-in bubble (TimeMilestone.pending): what they have got done so far, the same question as the
# hourly DM, which then shows the answer too (TimeCheckInDmJob). Answers what the pet shows, like
# TimersController. Only ever the signed-in user's own.
class TimeCheckInsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #update authorizes explicitly

  def update
    authorize current_user, :track_time?
    check_in = current_user.time_milestones.find_by_public_id!(params[:id])
    unless check_in.answered?
      return render(json: { error: "Say what you've gotten done first" }, status: :unprocessable_content) unless check_in.answer!(params[:done])

      TimeCheckInDmJob.perform_later(check_in)
    end

    render json: TrackedTimeSerializer.render(TrackedTime.new(current_user), huddle: Huddle.current)
  end
end
