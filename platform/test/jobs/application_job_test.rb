require "test_helper"

class ApplicationJobTest < ActiveJob::TestCase
  test "a batch enqueues its jobs together when it ends" do
    ApplicationJob.batch do
      ProgressRefreshJob.perform_later(1)
      ApplicationJob.batch { ProgressRefreshJob.perform_later(2) }
      assert_no_enqueued_jobs
    end
    assert_enqueued_jobs 2, only: ProgressRefreshJob
  end

  test "a batch drops jobs from a transaction that rolls back" do
    ApplicationJob.batch do
      ActiveRecord::Base.transaction do
        ProgressRefreshJob.perform_later(1)
        raise ActiveRecord::Rollback
      end
      ProgressRefreshJob.perform_later(2)
    end
    assert_enqueued_with(job: ProgressRefreshJob, args: [ 2 ])
    assert_enqueued_jobs 1
  end

  test "a job whose transaction outlives the batch is enqueued when it commits" do
    ActiveRecord::Base.transaction do
      ApplicationJob.batch { ProgressRefreshJob.perform_later(1) }
      assert_no_enqueued_jobs
    end
    assert_enqueued_with(job: ProgressRefreshJob, args: [ 1 ])
  end

  test "a batch still enqueues what it collected when the block raises" do
    assert_raises(RuntimeError) do
      ApplicationJob.batch do
        ProgressRefreshJob.perform_later(1)
        raise "boom"
      end
    end
    assert_enqueued_jobs 1
  end
end
