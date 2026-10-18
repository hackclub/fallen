# frozen_string_literal: true

# Per-action request and job timings at /admin/insights. Production only: it inserts a row from a new thread after
# every request, which would race the query budgets in tests.
ActiveInsights.enabled = Rails.env.production?
ActiveInsights.ignored_endpoints = %w[Rails::HealthController#show]

# Timings are all we keep. The engine records IP and user agent too, so drop them before they are written.
Rails.application.config.to_prepare do
  ActiveInsights::Request.before_save { self.ip_address = self.user_agent = nil }
end
