# Reads a transfer's project from the program it came from into its snapshot (ProjectTransfer#fetch!).
class FetchProjectTransferJob < ApplicationJob
  queue_as :background
  limits_concurrency key: ->(transfer) { transfer }, duration: 1.minute, on_conflict: :discard

  def perform(transfer)
    transfer.fetch! if transfer.pending? && transfer.fetchable?
  end
end
