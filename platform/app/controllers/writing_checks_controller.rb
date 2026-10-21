# The journal composer asks for a check of what it is about to post, then polls it until Pangram answers
# (WritingCheck). JSON only.
class WritingChecksController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized
  rate_limit to: 10, within: 1.minute, only: :create, by: -> { current_user.id }, with: -> { head :too_many_requests }

  def create
    authorize WritingCheck
    render json: payload(WritingCheck.start(current_user, params.expect(:body)))
  end

  def show
    check = WritingCheck.find_by_public_id!(params[:id])
    authorize check
    render json: payload(check)
  end

  private

  def payload(check) = { id: check.public_id, status: check.status, flagged: check.flagged? }
end
