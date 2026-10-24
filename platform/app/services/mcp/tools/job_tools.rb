# frozen_string_literal: true

module Mcp
  module Tools
    # /admin/jobs (Admin::JobsController, JobQueuesController, RecurringTasksController): Solid Queue through JobBoard.
    module JobTools
      def self.tools = Tools.tools_in(self)

      def self.find(ctx, id, query)
        ctx.authorize!([ :admin, :job ], query)
        job = SolidQueue::Job.find(id)
        ctx.subject!(job)
        job
      end

      class ListJobs < Mcp::Tool
        description "Jobs in one status, 25 to a page, with the count in every status. `query` matches the job class."
        arguments({ status: { type: "string", enum: JobBoard::STATUSES }, queue: { type: "string" }, query: { type: "string" },
                    **Compact.page_arguments }, required: %w[status])
        reads!

        def self.run(ctx, status:, queue: nil, query: nil, page: nil, per: nil)
          ctx.authorize!([ :admin, :job ], :index?)
          jobs = ctx.scope(SolidQueue::Job, policy_scope_class: Admin::JobPolicy::Scope)
          jobs = JobBoard.jobs(status, from: jobs, queue: queue.presence, search: query.presence)
          jobs = jobs.includes(:failed_execution) if status == "failed"
          list = Compact.paginate(jobs, page:, per:) do |rows|
            rows.map do |job|
              failure = job.failed_execution if status == "failed"
              { id: job.id, class: job.class_name, queue: job.queue_name, arguments: JobBoard.preview(job), attempts: JobBoard.attempts(job),
                error: failure && Compact.clip("#{failure.exception_class}: #{failure.message}", 200),
                createdAt: Compact.time(job.created_at), scheduledAt: Compact.time(job.scheduled_at), finishedAt: Compact.time(job.finished_at) }
            end
          end
          { counts: JobBoard.counts, **list }
        end
      end

      class GetJob < Mcp::Tool
        description "One job: its arguments and, if it failed, the error and the first 30 lines of the backtrace."
        arguments({ id: { type: "integer" } }, required: %w[id])
        reads!

        def self.run(ctx, id:)
          job = JobTools.find(ctx, id, :show?)
          status = JobBoard.status_of(job)
          detail = AdminJobDetailSerializer.render(job, status:).symbolize_keys
          detail.slice(:id, :class_name, :queue_name, :priority, :attempts, :error_message, :recurring_task, :created_at, :scheduled_at, :finished_at)
            .merge(status:, arguments: Compact.clip(detail[:arguments_json], 4_000), backtrace: detail[:backtrace].first(30))
        end
      end

      class GetJobSystem < Mcp::Tool
        description "Solid Queue's queues (size, latency, paused), worker processes and recurring tasks."
        arguments
        reads!

        def self.run(ctx)
          ctx.authorize!([ :admin, :job ], :index?)
          { queues: JobBoard.queues, workers: JobBoard.processes, recurring: JobBoard.recurring_tasks }
        end
      end

      class RetryJob < Mcp::Tool
        description "Put a failed job back on its queue, as Retry on /admin/jobs does."
        arguments({ id: { type: "integer" } }, required: %w[id])
        writes!

        def self.run(ctx, id:)
          job = JobTools.find(ctx, id, :update?)
          ctx.refuse!("Job #{id} hasn't failed.") unless job.failed_execution
          JobBoard.retry(job)
          { id: job.id, class: job.class_name, queued: true }
        end
      end

      class RunJobNow < Mcp::Tool
        description "Run a scheduled job now instead of at its time."
        arguments({ id: { type: "integer" } }, required: %w[id])
        writes!

        def self.run(ctx, id:)
          job = JobTools.find(ctx, id, :update?)
          ctx.refuse!("Job #{id} isn't scheduled.") unless job.scheduled_execution
          JobBoard.run_now(job)
          { id: job.id, class: job.class_name, queued: true }
        end
      end

      class DiscardJob < Mcp::Tool
        description "Throw away a job that is waiting or has failed. It can't be brought back. A running job can't be discarded."
        arguments({ id: { type: "integer" } }, required: %w[id])
        writes! destructive: true

        def self.run(ctx, id:)
          job = JobTools.find(ctx, id, :destroy?)
          ctx.refuse!("#{job.class_name} is running or finished, so it can't be discarded.") unless JobBoard.discard(job)
          { id: job.id, class: job.class_name, discarded: true }
        end
      end

      class RetryFailedJobs < Mcp::Tool
        description "Retry every failed job, or those matching `queue` and `query`, as Retry all on /admin/jobs does."
        arguments({ queue: { type: "string" }, query: { type: "string" } })
        writes!

        def self.run(ctx, queue: nil, query: nil)
          ctx.authorize!([ :admin, :job ], :update?)
          jobs = JobBoard.jobs("failed", queue: queue.presence, search: query.presence)
          count = jobs.count
          JobBoard.retry_all(jobs)
          { retried: count }
        end
      end

      class DiscardFailedJobs < Mcp::Tool
        description "Throw away every failed job, or those matching `queue` and `query`. They can't be brought back. " \
                    "Check list_jobs with the same filters first."
        arguments({ queue: { type: "string" }, query: { type: "string" } })
        writes! destructive: true

        def self.run(ctx, queue: nil, query: nil)
          ctx.authorize!([ :admin, :job ], :destroy?)
          jobs = JobBoard.jobs("failed", queue: queue.presence, search: query.presence)
          count = jobs.count
          JobBoard.discard_all(jobs)
          { discarded: count }
        end
      end

      class SetQueuePaused < Mcp::Tool
        description "Pause a queue so workers stop taking its jobs, or resume it."
        arguments({ name: { type: "string" }, paused: { type: "boolean" } }, required: %w[name paused])
        writes! idempotent: true

        def self.run(ctx, name:, paused:)
          ctx.authorize!([ :admin, :job ], :update?)
          queue = SolidQueue::Queue.find_by_name(name)
          paused ? queue.pause : queue.resume
          { queue: queue.name, paused: queue.paused? }
        end
      end

      class RunRecurringTask < Mcp::Tool
        description "Run a recurring task (config/recurring.yml) once now, outside its schedule. get_job_system lists the keys."
        arguments({ key: { type: "string" } }, required: %w[key])
        writes!

        def self.run(ctx, key:)
          ctx.authorize!([ :admin, :job ], :update?)
          task = SolidQueue::RecurringTask.find_by!(key:)
          ctx.refuse!("#{task.key} couldn't be queued. Try again in a moment.") unless task.enqueue(at: Time.current)
          { key: task.key, queued: true }
        end
      end
    end
  end
end
