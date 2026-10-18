# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production staging]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.send_default_pii = true
  config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)

  # Traffic is low enough to trace every request and job. The health check runs every few seconds and would drown them.
  traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 1.0).to_f
  config.traces_sampler = lambda do |context|
    next context[:parent_sampled] unless context[:parent_sampled].nil?
    next 0.0 if context.dig(:env, "PATH_INFO") == "/up" || context.dig(:env, "fallen.warmup")

    traces_sample_rate
  end

  # Ruby stacks for sampled traces, so a slow span shows which code spent the time. Relative to the traces above.
  config.profiler_class = Sentry::Vernier::Profiler
  config.profiles_sample_rate = ENV.fetch("SENTRY_PROFILES_SAMPLE_RATE", 1.0).to_f
end
