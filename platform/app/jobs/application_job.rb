class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked
  discard_on ActiveJob::DeserializationError

  # Changes a job makes are attributed to whoever enqueued it (nil for scheduled jobs) and tagged with the job.
  around_perform do |job, block|
    PaperTrail.request(whodunnit: job.paper_trail_whodunnit, controller_info: { source: "job:#{job.class.name}" }, &block)
  end

  attr_reader :paper_trail_whodunnit

  def serialize = super.merge("paper_trail_whodunnit" => PaperTrail.request.whodunnit)

  def deserialize(job_data)
    super
    @paper_trail_whodunnit = job_data["paper_trail_whodunnit"]
  end
end
