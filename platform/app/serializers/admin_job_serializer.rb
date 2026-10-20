# frozen_string_literal: true

# Admin-only. Rows in /admin/jobs. Takes the `status:` of the list (JobBoard::STATUSES), so rows don't look it up
# one by one; the controller preloads the execution that status reads.
class AdminJobSerializer < ApplicationSerializer
  typelize_from SolidQueue::Job
  typelize status: :string, arguments: :string, attempts: :number,
    error: [ "{ exception_class: string; message: string }", nullable: true ],
    failed_at: [ :string, nullable: true ], started_at: [ :string, nullable: true ], worker: [ :string, nullable: true ]

  attributes :id, :class_name, :queue_name, :priority, :created_at, :scheduled_at, :finished_at
  attribute(:status) { params[:status] }
  attribute(:arguments) { |job| JobBoard.preview(job) }
  attribute(:attempts) { |job| JobBoard.attempts(job) }
  attribute(:error) do |job|
    failure = job.failed_execution if params[:status] == "failed"
    failure && { exception_class: failure.exception_class, message: failure.message.to_s.truncate(300) }
  end
  attribute(:failed_at) { |job| job.failed_execution.created_at if params[:status] == "failed" }
  attribute(:started_at) { |job| job.claimed_execution.created_at if params[:status] == "in_progress" }
  attribute(:worker) { |job| job.claimed_execution.process&.name if params[:status] == "in_progress" }
end
