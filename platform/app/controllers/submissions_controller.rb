# Sending a project's design for review from the submit popup, and unsubmitting it while it waits.
class SubmissionsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized
  rate_limit to: 5, within: 1.minute, only: :create, by: -> { current_user.id }

  FLAG = :design_submissions

  def create
    project = Project.kept.find_by_public_id!(params[:project_id])
    authorize Submission.new(project:)
    raise Pundit::NotAuthorizedError unless Flipper.enabled?(FLAG, current_user)

    fields = params.expect(submission: [ :snapshot_id, :note, :bom_csv, made_with: [], screenshots: [], items: [ BomItem::FIELDS ] ])
    submission = Submission.submit(project:, user: current_user, snapshot: project.repo_snapshots.find_by_public_id(fields[:snapshot_id]),
      made_with: fields[:made_with], note: fields[:note], items: fields[:items]&.map(&:to_h), screenshots: fields[:screenshots], bom_csv: fields[:bom_csv])

    if submission.persisted?
      redirect_to project_path(project), notice: "Submitted! A reviewer will look at it soon."
    else
      inertia_errors(submission, fallback_location: project_path(project))
    end
  end

  def destroy
    submission = Submission.find_by_public_id!(params[:id])
    authorize submission
    submission.withdraw!
    redirect_to project_path(submission.project), notice: "Unsubmitted. Submit it again when it's ready."
  end
end
