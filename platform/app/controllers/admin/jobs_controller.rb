class Admin::JobsController < Admin::ApplicationController
  VIEWS = JobBoard::STATUSES + %w[queues workers recurring]

  before_action :set_job, only: %i[show retry run destroy]

  # One tab at a time: a status's jobs, or the queues, workers or recurring tasks. Counts for every tab arrive
  # alongside, so the tabs fill in while the table loads.
  def index
    authorize [ :admin, :job ]
    view = VIEWS.include?(params[:status]) ? params[:status] : "failed"
    filters = { queue: params[:queue].presence, search: params[:query].presence }
    jobs = policy_scope(SolidQueue::Job, policy_scope_class: Admin::JobPolicy::Scope)

    render inertia: "Admin/Jobs/Index", props: {
      status: view,
      queue: filters[:queue].to_s,
      query: filters[:search].to_s,
      counts: InertiaRails.defer(group: "counts") { JobBoard.counts },
      queue_names: InertiaRails.defer(group: "counts") { SolidQueue::Job.distinct.order(:queue_name).pluck(:queue_name) },
      **view_props(view, jobs, filters)
    }
  end

  def show
    render inertia: "Admin/Jobs/Show", props: {
      job: AdminJobDetailSerializer.render(@job, status: JobBoard.status_of(@job))
    }
  end

  def retry
    JobBoard.retry(@job)
    redirect_back_or_to admin_jobs_path, notice: "#{@job.class_name} is queued again."
  end

  # A scheduled job, now instead of later.
  def run
    JobBoard.run_now(@job)
    redirect_back_or_to admin_jobs_path(status: "scheduled"), notice: "#{@job.class_name} is queued to run now."
  end

  def destroy
    if JobBoard.discard(@job)
      # From the job's own page, which is gone now, back to the list it was in; from a list, back to that list.
      list = params[:return_to].presence_in(JobBoard::STATUSES)
      notice = "Discarded #{@job.class_name}."
      list ? redirect_to(admin_jobs_path(status: (list unless list == "failed")), notice:) : redirect_back_or_to(admin_jobs_path, notice:)
    else
      redirect_back_or_to admin_job_path(@job), alert: "#{@job.class_name} is running, so it can't be discarded."
    end
  end

  def retry_all
    authorize [ :admin, :job ], :update?
    jobs = failed_jobs
    count = jobs.count
    JobBoard.retry_all(jobs)
    redirect_to admin_jobs_path(**filter_params), notice: "Retrying #{helpers.pluralize(count, 'job')}."
  end

  def discard_all
    authorize [ :admin, :job ], :destroy?
    jobs = failed_jobs
    count = jobs.count
    JobBoard.discard_all(jobs)
    redirect_to admin_jobs_path(**filter_params), notice: "Discarded #{helpers.pluralize(count, 'failed job')}."
  end

  private

  def set_job
    @job = SolidQueue::Job.find(params[:id])
    authorize [ :admin, :job ], (action_name == "show" ? :show? : :update?)
  end

  # Bulk actions apply to what the failed tab shows: its queue and search filters.
  def failed_jobs
    JobBoard.jobs("failed", queue: params[:queue].presence, search: params[:query].presence)
  end

  def filter_params = { queue: params[:queue].presence, query: params[:query].presence }.compact

  def view_props(view, jobs, filters)
    case view
    when "queues" then { queues: InertiaRails.defer(group: "table") { JobBoard.queues } }
    when "workers" then { workers: InertiaRails.defer(group: "table") { JobBoard.processes } }
    when "recurring" then { recurring: InertiaRails.defer(group: "table") { JobBoard.recurring_tasks } }
    else
      jobs = JobBoard.jobs(view, from: jobs, **filters)
      preload = { "failed" => :failed_execution, "in_progress" => { claimed_execution: :process } }[view]
      deferred_table(preload ? jobs.includes(preload) : jobs, AdminJobSerializer, :jobs) { { status: view } }
    end
  end
end
