# "Invite me" on the pet's huddle prompt: rings the signed-in user into the huddle (HuddleRingJob). The prompt
# opens the huddle's link itself.
class HuddleInvitesController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #create authorizes explicitly
  rate_limit to: 5, within: 1.minute, only: :create, by: -> { current_user.id }, with: -> { head :too_many_requests }

  def create
    authorize current_user, :track_time?
    HuddleRingJob.perform_later(current_user)
    head :accepted
  end
end
