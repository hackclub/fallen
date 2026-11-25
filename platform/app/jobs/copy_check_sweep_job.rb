# Every decision waiting for sign-off gets a copy check: the first run, and the retries of one that couldn't finish.
class CopyCheckSweepJob < ApplicationJob
  queue_as :background

  def perform
    return unless CopyCheck.available?

    Submission.awaiting_sign_off.where("copy_check IS NULL OR copy_check->>'status' = 'pending'").find_each { CopyCheckJob.perform_later(it) }
  end
end
