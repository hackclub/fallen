# Sends an approved design to the YSWS Project Submission table (YswsSubmission). It reads Hack Club Auth and writes to
# Airtable, so it runs here and not in the review's request. Does nothing until the table is configured.
class YswsSubmissionJob < ApplicationJob
  queue_as :background
  # Airtable answering with an error made no row, so it's safe to send again. A timeout may have made one: that job
  # fails and waits in the failed list, to be retried by hand once the table is checked (as Fallout's does).
  retry_on Airtable::Error, wait: :polynomially_longer, attempts: 5

  def perform(submission) = YswsSubmission.upload(submission)
end
