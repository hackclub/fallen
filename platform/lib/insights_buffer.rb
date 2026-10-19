# frozen_string_literal: true

# Collects the rows for /admin/insights (ActiveInsights) and writes them in batches from one thread per process.
# The engine's own subscribers start a thread and run an INSERT with its own commit for every request, which cost
# 2ms per request and 40ms at p90 on the one-CPU production pod. Wired up in config/initializers/active_insights.rb.
class InsightsBuffer
  FLUSH_EVERY = 5 # seconds
  MAX_ROWS = 1_000 # per table; beyond it the oldest are dropped rather than the buffer growing without bound

  class << self
    def instance = @instance ||= new
    delegate :request, :job, :flush, to: :instance
  end

  def initialize
    @lock = Mutex.new
    @rows = { ActiveInsights::Request => [], ActiveInsights::Job => [] }
  end

  # The same columns ActiveInsights::Request.setup writes, without the IP and user agent (docs/privacy.md).
  def request(started, finished, unique_id, payload)
    add(ActiveInsights::Request, started, finished, unique_id,
      http_method: payload[:method], **payload.slice(:controller, :action, :format, :status, :view_runtime, :db_runtime, :path))
  end

  def job(started, finished, unique_id, payload)
    job = payload[:job]
    add(ActiveInsights::Job, started, finished, unique_id,
      job: job.class.name, queue: job.queue_name, db_runtime: payload[:db_runtime], scheduled_at: job.scheduled_at,
      queue_time: job.scheduled_at ? (started - job.scheduled_at) * 1000.0 : 0.0)
  end

  def flush
    batches = @lock.synchronize { @rows.to_h { |model, rows| [ model, rows.dup ] }.tap { @rows.each_value(&:clear) } }
    batches.each { |model, rows| model.insert_all(rows) if rows.any? }
  end

  private

  def add(model, started, finished, unique_id, **attributes)
    row = { started_at: started, finished_at: finished, uuid: unique_id, duration: (finished - started) * 1000.0, **attributes }
    @lock.synchronize do
      @rows[model] << row
      @rows[model].shift if @rows[model].size > MAX_ROWS
      start_flusher
    end
  end

  # Started by the first row in each process, so a Puma worker forked after boot gets its own thread.
  def start_flusher
    return if @flusher&.alive? && @flusher_pid == Process.pid

    @flusher_pid = Process.pid
    @flusher = Thread.new do
      loop do
        sleep FLUSH_EVERY
        Rails.application.executor.wrap { flush }
      rescue => error
        Rails.logger.error("[insights] flush failed: #{error.class}: #{error.message}")
      end
    end
  end
end
