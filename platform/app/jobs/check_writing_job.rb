# Asks Pangram about a WritingCheck while the person waits on "Checking…", so it gives up quickly: a check that
# fails or takes too long lets the journal through.
class CheckWritingJob < ApplicationJob
  queue_as :realtime

  POLL_EVERY = 0.5
  GIVE_UP_AFTER = 20

  def perform(check)
    return unless check.pending?

    task = Pangram.submit(check.body)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + GIVE_UP_AFTER
    until (result = Pangram.result(task))
      return check.update!(status: "failed") if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep POLL_EVERY
    end
    check.update!(status: "done", fraction_ai: result["fraction_ai"], fraction_ai_assisted: result["fraction_ai_assisted"])
    ReportWritingFlagJob.perform_later(check) if check.flagged?
  rescue Faraday::Error, Pangram::Error, JSON::ParserError, KeyError => e
    Rails.error.report(e, handled: true)
    check.update!(status: "failed")
  end
end
