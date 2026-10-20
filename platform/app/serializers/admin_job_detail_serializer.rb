# frozen_string_literal: true

# Admin-only. Everything on /admin/jobs/:id: the full arguments and, for a failed job, the backtrace.
class AdminJobDetailSerializer < AdminJobSerializer
  typelize arguments_json: :string, active_job_id: :string, concurrency_key: [ :string, nullable: true ],
    backtrace: "string[]", error_message: [ :string, nullable: true ], recurring_task: [ :string, nullable: true ]

  attributes :active_job_id, :concurrency_key
  attribute(:arguments_json) { |job| JSON.pretty_generate(JobBoard.arguments(job)) }
  attribute(:error_message) { |job| job.failed_execution.message if params[:status] == "failed" }
  # Paths from the app's root and the gem's own folder, not the machine's: app/jobs/x.rb, activejob-8.1/lib/....
  # Matched by folder rather than Rails.root, since the worker that failed may have run from elsewhere.
  attribute(:backtrace) do |job|
    lines = params[:status] == "failed" ? Array(job.failed_execution.backtrace) : []
    lines.map do |line|
      if line.include?("/gems/") then line.sub(%r{\A\S*/gems/}, "")
      elsif line.include?("/ruby/") then line
      else line.sub(%r{\A/\S*?/(?=(?:app|lib|config|db)/)}, "")
      end
    end
  end
  attribute(:recurring_task) { |job| SolidQueue::RecurringExecution.where(job_id: job.id).pick(:task_key) }
end
