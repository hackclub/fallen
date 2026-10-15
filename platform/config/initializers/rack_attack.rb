# frozen_string_literal: true

class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Slack webhooks are signature-verified in SlackController; never throttle them by IP.
  safelist("slack webhooks") { |req| req.path.start_with?("/slack/") }
  safelist("health check") { |req| req.path == "/up" }
  # In development there's nothing to protect locally, and one page load is hundreds of requests (every Vite module and
  # asset is proxied through Rails, plus the profiler's), so never throttle your own machine.
  safelist("local development") { |req| Rails.env.development? && %w[127.0.0.1 ::1].include?(req.ip) }

  throttle("req/ip", limit: 300, period: 5.minutes, &:ip)

  throttle("auth/start/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/auth/hca/start"
  end

  throttle("auth/callback/ip", limit: 20, period: 1.minute) do |req|
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
