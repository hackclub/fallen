# frozen_string_literal: true

# Hack Club Auth (https://auth.hackclub.com) OAuth + identity API.
# Set HCA_CLIENT_ID / HCA_CLIENT_SECRET. Development talks to the HCA staging instance by default.
module HCA
  class Error < StandardError; end

  module_function

  def host
    ENV.fetch("HCA_HOST") { Rails.env.production? ? "https://auth.hackclub.com" : "https://hca.dinosaurbbq.org" }
  end

  def scopes
    ENV.fetch("HCA_SCOPES") { "openid profile email name slack_id verification_status birthdate" }
  end

  def configured? = ENV["HCA_CLIENT_ID"].present? && ENV["HCA_CLIENT_SECRET"].present?

  # `login_hint` fills in the email on HCA's sign-in page.
  def authorize_url(redirect_uri, state, login_hint: nil)
    params = {
      client_id: ENV.fetch("HCA_CLIENT_ID", nil),
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: scopes,
      state: state,
      login_hint: login_hint.presence
    }.compact
    "#{host}/oauth/authorize?#{params.to_query}"
  end

  def exchange_code_for_token(code, redirect_uri)
    response = connection.post("/oauth/token") do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        client_id: ENV.fetch("HCA_CLIENT_ID", nil),
        client_secret: ENV.fetch("HCA_CLIENT_SECRET", nil)
      }.to_query
    end

    unless response.success?
      Rails.logger.error("HCA token exchange failed: #{response.status} #{response.body}")
      return nil
    end

    JSON.parse(response.body)
  end

  def me(access_token)
    raise ArgumentError, "access_token is required" if access_token.blank?

    response = connection.get("/api/v1/me") do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
      req.headers["Accept"] = "application/json"
    end

    unless response.success?
      Rails.logger.warn("HCA /api/v1/me failed: #{response.status}")
      return nil
    end

    JSON.parse(response.body)
  end

  def identity(access_token) = me(access_token)&.dig("identity") || {}

  def adult?(identity)
    birthday = identity["birthday"].presence or return false
    Date.parse(birthday) <= 18.years.ago.to_date
  rescue ArgumentError
    false
  end

  # Whether an email has a Hack Club Auth account. The browser asks this directly (CORS is open), so the landing
  # page can send people who have one straight to HCA.
  def check_email_url = "#{host}/api/external/check"

  def portal_url(path, return_to:)
    uri = URI.join(host, "/portal/#{path}")
    uri.query = { return_to: return_to }.to_query
    uri.to_s
  end

  def connection
    @connection ||= Faraday.new(url: host) do |f|
      f.options.timeout = 10
      f.options.open_timeout = 5
    end
  end
end
