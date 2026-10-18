class SyncLapseTimelapsesJob < ApplicationJob
  queue_as :realtime
  limits_concurrency key: ->(user) { user }, duration: 1.minute, on_conflict: :discard
  retry_on Faraday::Error, Lapse::Error, wait: 5.seconds, attempts: 3

  def perform(user)
    return unless user.lapse_connected?

    LapseTimelapse.sync(user)
  end
end
