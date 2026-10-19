# frozen_string_literal: true

# Per-action request and job timings at /admin/insights. Production only: it inserts rows from another thread,
# which would race the query budgets in tests. The engine's own subscribers stay off (`enabled`): each ran a thread
# and an INSERT per request. InsightsBuffer records the same rows and writes them in batches. Timings are all we
# keep: it leaves out the IP and user agent the engine would record.
ActiveInsights.enabled = false
ActiveInsights.ignored_endpoints = %w[Rails::HealthController#show]

if Rails.env.production?
  ActiveSupport::Notifications.subscribe("process_action.action_controller") do |_name, started, finished, unique_id, payload|
    # Puma's boot-time requests (config/warmup.rb) are not traffic.
    next if ActiveInsights.ignored_endpoint?(payload) || payload[:request]&.env&.key?("fallen.warmup")

    InsightsBuffer.request(started, finished, unique_id, payload)
  end

  ActiveSupport::Notifications.subscribe("perform.active_job") do |_name, started, finished, unique_id, payload|
    InsightsBuffer.job(started, finished, unique_id, payload)
  end

  at_exit { InsightsBuffer.flush rescue nil }
end
