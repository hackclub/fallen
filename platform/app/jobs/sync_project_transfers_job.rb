# Copies the transfer form's rows from Airtable (ProjectTransfer.sync, config/recurring.yml) and fetches the projects
# not read yet. Does nothing until Airtable is configured.
class SyncProjectTransfersJob < ApplicationJob
  queue_as :background
  limits_concurrency to: 1, key: "project_transfers", duration: 10.minutes

  def perform
    return unless Airtable.configured?

    ProjectTransfer.sync
    ActiveJob.perform_all_later(ProjectTransfer.kept.pending.unfetched.map { FetchProjectTransferJob.new(it) })
  end
end
