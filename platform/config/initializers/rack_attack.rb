# frozen_string_literal: true

class Rack::Attack
  # Puma runs several workers (WEB_CONCURRENCY), so production counts in the shared Solid Cache; a per-process store
  # would hand every worker its own allowance. Tests use the null store, so they get a MemoryStore.
  Rack::Attack.cache.store = Rails.env.production? ? Rails.cache : ActiveSupport::Cache::MemoryStore.new

  # Slack webhooks are signature-verified in SlackController; never throttle them by IP.
  safelist("slack webhooks") { |req| req.path.start_with?("/slack/") }
  safelist("health check") { |req| req.path == "/up" }
  # Puma's boot-time requests (config/warmup.rb); only an in-process request can carry this env key.
  safelist("warmup") { |req| req.env["fallen.warmup"] }
  # In development there's nothing to protect locally, and one page load is hundreds of requests (every Vite module and
  # asset is proxied through Rails, plus the profiler's), so never throttle your own machine.
  safelist("local development") { |req| Rails.env.development? && %w[127.0.0.1 ::1].include?(req.ip) }

  # A school or event puts a whole room behind one IP, so signed-in traffic counts per person (the session cookie is
  # encrypted, so the id can't be forged) and only signed-out traffic counts per IP, with room for a classroom.
  throttle("req/user", limit: 300, period: 5.minutes) { |req| req.session[:user_id] }
  throttle("req/ip", limit: 1500, period: 5.minutes) { |req| req.ip if req.session[:user_id].blank? }

  # Each upload holds a Puma thread while it goes on to R2 (UploadsController).
  throttle("uploads/user", limit: 60, period: 10.minutes) do |req|
    req.session[:user_id] if req.post? && req.path == "/uploads"
  end

  throttle("auth/start/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path == "/auth/hca/start"
  end

  # Each one can make an account.
  throttle("trial_session/ip", limit: 30, period: 10.minutes) do |req|
    req.ip if req.post? && req.path == "/trial_session"
  end

  throttle("auth/callback/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path == "/auth/hca/callback"
  end

  blocklist("fail2ban pentesters") do |req|
    Rack::Attack::Fail2Ban.filter("pentesters-#{req.ip}", maxretry: 5, findtime: 10.minutes, bantime: 1.hour) do
      CGI.unescape(req.query_string).include?("/etc/passwd") ||
        req.path.include?("/etc/passwd") ||
        req.path.include?("wp-admin") ||
        req.path.include?("wp-login") ||
        req.path.end_with?(".php")
    end
  end

  # Since rack-attack 6.7 the responders get the Rack::Attack::Request, not the env hash.
  self.throttled_responder = lambda do |request|
    retry_after = request.env["rack.attack.match_data"][:period]
    [ 429, { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s }, [ "Too many requests. Please try again later.\n" ] ]
  end

  self.blocklisted_responder = ->(_env) { [ 403, { "Content-Type" => "text/plain" }, [ "Forbidden\n" ] ] }
end
