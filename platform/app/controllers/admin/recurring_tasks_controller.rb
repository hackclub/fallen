# Runs a recurring task (config/recurring.yml) once now, outside its schedule.
class Admin::RecurringTasksController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #run authorizes explicitly

  def run
    authorize [ :admin, :job ], :update?
    task = SolidQueue::RecurringTask.find_by!(key: params[:key])

    if task.enqueue(at: Time.current)
      redirect_back_or_to admin_jobs_path(status: "recurring"), notice: "#{task.key} is queued to run now."
    else
      redirect_back_or_to admin_jobs_path(status: "recurring"), alert: "#{task.key} couldn't be queued. Try again in a moment."
    end
  end
end
