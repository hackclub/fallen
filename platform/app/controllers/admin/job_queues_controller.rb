# Pausing a Solid Queue queue stops workers taking its jobs; they wait in the queue until it is resumed.
class Admin::JobQueuesController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #update authorizes explicitly

  def update
    authorize [ :admin, :job ], :update?
    queue = SolidQueue::Queue.find_by_name(params[:name])
    paused = ActiveModel::Type::Boolean.new.cast(params.expect(:paused))
    paused ? queue.pause : queue.resume

    Rails.logger.info({ event: "job_queue.#{paused ? 'pause' : 'resume'}", admin_id: true_user.id, queue: queue.name }.to_json)
    redirect_back_or_to admin_jobs_path(status: "queues"), notice: "#{queue.name} is #{paused ? 'paused' : 'running again'}."
  end
end
