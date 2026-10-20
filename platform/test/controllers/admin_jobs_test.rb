require "test_helper"

class AdminJobsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "failed jobs are the first tab, with their error and attempts" do
    job = failed_job("SyncUsersToAirtableJob", "Airtable said no")
    props = inertia_props(admin_jobs_path, "Admin/Jobs/Index")
    assert_equal "failed", props["status"]
    assert_not props.key?("jobs"), "rows are deferred"

    props = load_deferred(admin_jobs_path, "Admin/Jobs/Index", "jobs", "pagy", "counts")
    row = props["jobs"].sole
    assert_equal [ job.id, "failed", 3 ], row.values_at("id", "status", "attempts")
    assert_equal({ "exception_class" => "RuntimeError", "message" => "Airtable said no" }, row["error"])
    assert_equal "\"User#1\", 2", row["arguments"]
    assert_equal 1, props["counts"]["failed"]
  end

  test "each status lists only its own jobs, filtered by queue and class" do
    failed_job("CloseWeekJob")
    later = enqueue("TimeMilestoneJob", queue: "slack", at: 1.hour.from_now)
    enqueue("HuddleSyncJob", queue: "realtime")

    rows = load_deferred(admin_jobs_path(status: "scheduled"), "Admin/Jobs/Index", "jobs")["jobs"]
    assert_equal [ later.id ], rows.pluck("id")

    rows = load_deferred(admin_jobs_path(status: "queued", queue: "realtime"), "Admin/Jobs/Index", "jobs")["jobs"]
    assert_equal [ "HuddleSyncJob" ], rows.pluck("class_name")

    rows = load_deferred(admin_jobs_path(status: "queued", query: "milestone"), "Admin/Jobs/Index", "jobs")["jobs"]
    assert_empty rows, "the scheduled job is not queued yet"
  end

  test "the job page shows its arguments and the backtrace of a failure" do
    job = failed_job("CloseWeekJob")
    props = inertia_props(admin_job_path(job), "Admin/Jobs/Show")["job"]
    assert_equal "failed", props["status"]
    assert_includes props["arguments_json"], "User#1"
    assert props["backtrace"].any? { it.include?("admin_jobs_test.rb") }
  end

  test "retrying puts a failed job back in its queue" do
    job = failed_job("CloseWeekJob")
    post retry_admin_job_path(job)
    assert_redirected_to admin_jobs_path
    assert job.reload.ready_execution
    assert_nil job.failed_execution
  end

  test "discarding deletes a waiting job but not a running one" do
    job = enqueue("CloseWeekJob", at: 1.hour.from_now)
    delete admin_job_path(job, return_to: "scheduled")
    assert_redirected_to admin_jobs_path(status: "scheduled")
    assert_not SolidQueue::Job.exists?(job.id)

    running = enqueue("CloseWeekJob")
    running.ready_execution.destroy!
    worker = SolidQueue::Process.register(kind: "Worker", pid: 1, name: "worker-0")
    SolidQueue::ClaimedExecution.create!(job: running, process: worker)
    delete admin_job_path(running)
    assert_equal "CloseWeekJob is running, so it can't be discarded.", flash[:alert]
    assert SolidQueue::Job.exists?(running.id)
  end

  test "a scheduled job can run now" do
    job = enqueue("CloseWeekJob", at: 1.day.from_now)
    post run_admin_job_path(job)
    assert job.reload.ready_execution
    assert_nil job.scheduled_execution
  end

  test "bulk retry and discard apply to the failed jobs the filters show" do
    kept = failed_job("CloseWeekJob")
    retried = failed_job("SyncUsersToAirtableJob")

    post retry_all_admin_jobs_path(query: "airtable")
    assert_redirected_to admin_jobs_path(query: "airtable")
    assert_equal "Retrying 1 job.", flash[:notice]
    assert retried.reload.ready_execution
    assert kept.reload.failed_execution

    post discard_all_admin_jobs_path
    assert_not SolidQueue::Job.exists?(kept.id)
  end

  test "queues can be paused and resumed" do
    enqueue("HuddleSyncJob", queue: "realtime")
    patch admin_job_queue_path("realtime"), params: { paused: true }
    assert SolidQueue::Queue.find_by_name("realtime").paused?

    queues = load_deferred(admin_jobs_path(status: "queues"), "Admin/Jobs/Index", "queues")["queues"]
    assert_equal [ { "name" => "realtime", "size" => 1, "paused" => true } ], queues.map { it.slice("name", "size", "paused") }

    patch admin_job_queue_path("realtime"), params: { paused: false }
    assert_not SolidQueue::Queue.find_by_name("realtime").paused?
  end

  test "workers and recurring tasks list with their health and schedule" do
    SolidQueue::Process.register(kind: "Worker", pid: 42, name: "worker-1", hostname: "web", metadata: { queues: "*", thread_pool_size: 3 })
    SolidQueue::RecurringTask.create!(key: "close_week", class_name: "CloseWeekJob", schedule: "every hour")

    workers = load_deferred(admin_jobs_path(status: "workers"), "Admin/Jobs/Index", "workers")["workers"]
    assert_equal [ [ "worker-1", true, 3 ] ], workers.map { it.values_at("name", "alive", "threads") }

    tasks = load_deferred(admin_jobs_path(status: "recurring"), "Admin/Jobs/Index", "recurring")["recurring"]
    assert_equal [ [ "close_week", "CloseWeekJob", nil ] ], tasks.map { it.values_at("key", "job", "last_run_at") }

    # Tests run jobs through the test adapter, so the task enqueues there rather than into Solid Queue.
    assert_enqueued_with(job: CloseWeekJob) { post run_admin_recurring_task_path("close_week") }
  end

  private

  def enqueue(class_name, queue: "default", at: nil)
    SolidQueue::Job.create!(class_name:, queue_name: queue, scheduled_at: at || Time.current, active_job_id: SecureRandom.uuid,
      arguments: { "job_class" => class_name, "arguments" => [ { "_aj_globalid" => "gid://fallen/User/1" }, 2 ], "executions" => 3 })
  end

  def failed_job(class_name, message = "boom")
    enqueue(class_name).tap do |job|
      job.ready_execution.destroy!
      raise message
    rescue => error
      job.failed_with(error)
    end
  end
end
