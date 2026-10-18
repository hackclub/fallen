# frozen_string_literal: true

# Puma's master runs this once before it forks the workers (config/puma.rb). A new process answers its first
# requests several times slower while YJIT compiles the hot paths, and a deploy sends every open tab to the new pod
# at once (Action Cable reconnects, the pet refetches its timer), so each deploy used to put seconds on a burst of
# requests. The workers inherit the compiled code, and the pod only passes its readiness probe once they accept, so
# the old pod keeps serving until this one is warm.
#
# The requests go through the whole Rack stack as the most recently seen person, each inside a transaction that is
# rolled back, so nothing they write (last_seen_at, cache entries, jobs) is kept. Sentry tracing, Active Insights and
# Rack::Attack skip them (the "fallen.warmup" env key, which only an in-process request can set).
module Warmup
  ROUNDS = Integer(ENV.fetch("WARMUP_ROUNDS", 150)) # YJIT compiles a method after 120 calls in an app this size
  TIME_LIMIT = 120 # seconds; the startup probe gives up after 450
  ENV_KEY = "fallen.warmup"

  def self.run
    return if ROUNDS.zero?

    user = User.on_a_team.order(last_seen_at: :desc).first
    return Rails.logger.info("[warmup] skipped: nobody to sign in as") unless user

    requests = requests_for(user)
    return Rails.logger.warn("[warmup] skipped: every request failed") if requests.empty?

    insights, ActiveInsights.enabled = ActiveInsights.enabled, false
    started = now
    times = []

    ROUNDS.times do
      round = now
      requests.each { |request| call(*request) }
      times << now - round
      break if now - started > TIME_LIMIT
    end

    Rails.logger.info(format("[warmup] %d rounds of %d requests in %.1fs; first round %.0fms, last %.0fms, YJIT %s",
      times.size, requests.size, now - started, times.first * 1000, times.last * 1000, defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? "on" : "off"))
  rescue => error
    # Never keep the pod from booting: a cold worker is slow, not broken.
    Rails.logger.error("[warmup] stopped: #{error.class}: #{error.message}")
  ensure
    ActiveInsights.enabled = insights unless insights.nil?
    ActiveRecord::Base.connection_handler.connection_pool_list(:all).each(&:disconnect!)
  end

  # The pages people actually sit on: the pet's timer (asked for on every page), Home and its deferred props, the
  # project pages, each as a first load (HTML) and as an Inertia visit (JSON). Project deferred props are left out
  # because they can call Lapse.
  def self.requests_for(user)
    signed_in = { "HTTP_COOKIE" => session_cookie(user) }
    inertia = signed_in.merge("HTTP_X_INERTIA" => "true", "HTTP_X_INERTIA_VERSION" => InertiaRails.configuration.version.to_s)
    project = user.projects.kept.order(updated_at: :desc).first
    paths = Rails.application.routes.url_helpers

    requests = [
      [ paths.timer_path(format: :json), signed_in ],
      [ paths.home_path, signed_in ],
      [ paths.home_path, inertia ],
      [ paths.home_path, inertia.merge("HTTP_X_INERTIA_PARTIAL_COMPONENT" => "Home/Index", "HTTP_X_INERTIA_PARTIAL_DATA" => "projects,stats,xp,activity") ],
      [ paths.projects_path, inertia ],
      [ paths.docs_path, inertia ],
      [ paths.root_path, {} ]
    ]
    requests += [ [ paths.project_path(project), signed_in ], [ paths.project_path(project), inertia ] ] if project

    # A request that fails or redirects (the sign-in did not take) would only warm the error page.
    requests.select do |path, headers|
      status = call(path, headers)
      (200..299).cover?(status).tap { |ok| Rails.logger.warn("[warmup] dropping #{path}: #{status}") unless ok }
    end
  end

  def self.call(path, headers)
    env = Rack::MockRequest.env_for("https://#{host}#{path}", headers.merge(ENV_KEY => true, **origin))
    status = nil
    ActiveRecord::Base.transaction do
      status, _headers, body = Rails.application.call(env)
      body.close if body.respond_to?(:close)
      raise ActiveRecord::Rollback
    end
    status
  end

  # The same encrypted cookie the session store writes after a sign-in (Authentication#sign_in).
  def self.session_cookie(user)
    key = Rails.application.config.session_options.fetch(:key)
    jar = ActionDispatch::Request.new(Rack::MockRequest.env_for("https://#{host}/", origin).merge(Rails.application.env_config)).cookie_jar
    jar.encrypted[key] = { value: { "session_id" => SecureRandom.hex(16), "user_id" => user.id } } # no session_id reads as no session
    "#{key}=#{CGI.escape(jar[key])}"
  end

  def self.host = ENV.fetch("APP_HOST", "localhost")
  def self.origin = { "HTTP_HOST" => host, "REMOTE_ADDR" => "127.0.0.1" } # env_for sets neither; host authorization needs both
  def self.now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
