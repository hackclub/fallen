# frozen_string_literal: true

# What /admin/jobs shows of Solid Queue. A job's status is which execution table holds it, so each status is a
# join rather than a column; every list here is one indexed query.
module JobBoard
  STATUSES = %w[failed in_progress queued scheduled blocked finished].freeze

  # The execution that holds a job in each status (a finished job has none).
  EXECUTIONS = {
    "failed" => :failed_execution,
    "in_progress" => :claimed_execution,
    "queued" => :ready_execution,
    "scheduled" => :scheduled_execution,
    "blocked" => :blocked_execution
  }.freeze

  module_function

  def jobs(status, queue: nil, search: nil, from: SolidQueue::Job.all)
    jobs = from
    jobs = jobs.where(queue_name: queue) if queue.present?
    jobs = jobs.where("solid_queue_jobs.class_name ILIKE ?", "%#{SolidQueue::Job.sanitize_sql_like(search)}%") if search.present?

    case status
    when "failed" then jobs.joins(:failed_execution).order("solid_queue_failed_executions.id DESC")
    when "in_progress" then jobs.joins(:claimed_execution).order("solid_queue_claimed_executions.id")
    when "queued" then jobs.joins(:ready_execution).order("solid_queue_ready_executions.priority, solid_queue_ready_executions.job_id")
    when "scheduled" then jobs.joins(:scheduled_execution).order("solid_queue_scheduled_executions.scheduled_at, solid_queue_scheduled_executions.job_id")
    when "blocked" then jobs.joins(:blocked_execution).order("solid_queue_blocked_executions.job_id")
    else jobs.finished.order(finished_at: :desc)
    end
  end

  def counts
    {
      failed: SolidQueue::FailedExecution.count,
      in_progress: SolidQueue::ClaimedExecution.count,
      queued: SolidQueue::ReadyExecution.count,
      scheduled: SolidQueue::ScheduledExecution.count,
      blocked: SolidQueue::BlockedExecution.count,
      finished: SolidQueue::Job.finished.count
    }
  end

  def status_of(job)
    job.finished? ? "finished" : EXECUTIONS.find { |_, execution| job.public_send(execution) }&.first
  end

  # Ready, size and latency of every queue, paused or not, in one query each.
  def queues
    names = (SolidQueue::Job.distinct.pluck(:queue_name) | SolidQueue::Pause.pluck(:queue_name)).sort
    ready = SolidQueue::ReadyExecution.group(:queue_name).pluck(:queue_name, Arel.sql("COUNT(*)"), Arel.sql("MIN(created_at)"))
      .to_h { |name, size, oldest| [ name, { size:, oldest: } ] }
    paused = SolidQueue::Pause.pluck(:queue_name).to_set

    names.map do |name|
      size, oldest = ready.fetch(name, {}).values_at(:size, :oldest)
      { name:, size: size.to_i, latency: oldest ? (Time.current - oldest).round : 0, paused: paused.include?(name) }
    end
  end

  def processes
    claimed = SolidQueue::ClaimedExecution.group(:process_id).count
    SolidQueue::Process.order(:kind, :name).map do |process|
      { name: process.name, kind: process.kind, hostname: process.hostname, pid: process.pid,
        last_heartbeat_at: process.last_heartbeat_at.iso8601, alive: process.last_heartbeat_at > SolidQueue.process_alive_threshold.ago,
        queues: Array(process.metadata["queues"]).join(", ").presence, threads: process.metadata["thread_pool_size"],
        claimed: claimed.fetch(process.id, 0) }
    end
  end

  def recurring_tasks
    last_runs = SolidQueue::RecurringExecution.group(:task_key).maximum(:run_at)
    SolidQueue::RecurringTask.order(:key).map do |task|
      { key: task.key, schedule: task.schedule, job: task.class_name || task.command, queue: task.queue_name,
        last_run_at: last_runs[task.key]&.iso8601, next_run_at: task.next_time.iso8601 }
    end
  end

  # Failed jobs go back to their queue with their attempt count reset.
  def retry(job) = job.failed_execution&.retry

  # Waiting jobs can be discarded; a running one can't, it has to finish or fail.
  def discard(job)
    execution = job.failed_execution || job.ready_execution || job.scheduled_execution || job.blocked_execution
    execution ? execution.discard : false
  end

  def run_now(job) = SolidQueue::ScheduledExecution.dispatch_jobs([ job.id ])

  def retry_all(jobs) = jobs.reorder(nil).in_batches(of: 500) { SolidQueue::FailedExecution.retry_all(it.to_a) }
  def discard_all(jobs) = jobs.reorder(nil).in_batches(of: 500) { SolidQueue::FailedExecution.discard_all_from_jobs(it.to_a) }

  # The arguments the job was called with, without Active Job's serialization markers. Records show as `User#12`.
  def arguments(job) = readable(job.arguments.fetch("arguments", []))
  def attempts(job) = job.arguments["executions"].to_i
  def preview(job) = arguments(job).map { it.is_a?(String) ? it.inspect : it.to_json }.join(", ").truncate(160)

  def readable(value)
    case value
    when Array then value.map { readable(it) }
    when Hash
      if (gid = value["_aj_globalid"]) then gid.delete_prefix("gid://").split("/", 2).last.sub("/", "#")
      elsif value.key?("_aj_serialized") then readable(value["value"])
      else value.reject { |key, _| key.start_with?("_aj_") }.transform_values { readable(it) }
      end
    else value
    end
  end
end
