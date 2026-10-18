# frozen_string_literal: true

# Lapse (https://lapse.hackclub.com), Hack Club's timelapse recorder. People connect it over OAuth (PKCE) so their
# journals can pick a timelapse, whose recorded time becomes the journal's hours. Set LAPSE_CLIENT_ID /
# LAPSE_CLIENT_SECRET. Access tokens last 30 days and Lapse issues no refresh tokens, so a 401 means connect again.
module Lapse
  class Error < StandardError; end
  class Unauthorized < Error; end

  SCOPES = "user:read timelapse:read"
  PAGE_SIZE = 100
  MAX_PAGES = 10

  module_function

  def host = ENV.fetch("LAPSE_HOST", "https://api.lapse.hackclub.com")
  def web_host = ENV.fetch("LAPSE_WEB_HOST", "https://lapse.hackclub.com")
  def configured? = ENV["LAPSE_CLIENT_ID"].present? && ENV["LAPSE_CLIENT_SECRET"].present?
  def timelapse_url(id) = "#{web_host}/timelapse/#{id}"

  def authorize_url(redirect_uri, state, code_verifier:)
    params = {
      client_id: ENV.fetch("LAPSE_CLIENT_ID", nil),
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: SCOPES,
      state: state,
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false),
      code_challenge_method: "S256"
    }
    "#{host}/api/auth/authorize?#{params.to_query}"
  end

  # Returns the access token.
  def exchange_code(code, redirect_uri, code_verifier:)
    response = connection.post("/api/auth/token") do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        client_id: ENV.fetch("LAPSE_CLIENT_ID", nil),
        client_secret: ENV.fetch("LAPSE_CLIENT_SECRET", nil),
        code_verifier: code_verifier
      }.to_query
    end
    raise Error, "Lapse token exchange failed (#{response.status})" unless response.success?

    JSON.parse(response.body)["access_token"].presence || raise(Error, "Lapse did not return an access token")
  end

  # Every timelapse the person owns, newest first, as Lapse's own hashes.
  def timelapses(access_token)
    pages = []
    cursor = nil
    MAX_PAGES.times do
      data = get("/api/timelapse/myPublishedTimelapses", access_token, { limit: PAGE_SIZE, cursor: cursor }.compact)
      pages.concat(Array(data["timelapses"]))
      cursor = data["nextCursor"] or break
    end
    pages
  end

  def connection
    Faraday.new(url: host) do |f|
      f.options.open_timeout = 5
      f.options.timeout = 15
    end
  end

  def get(path, access_token, params)
    response = connection.get(path, params) do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
      req.headers["Accept"] = "application/json"
    end
    raise Unauthorized, "Lapse token expired or was revoked" if response.status == 401
    raise Error, "Lapse #{path} failed (#{response.status})" unless response.success?

    JSON.parse(response.body).fetch("data")
  end
  private_class_method :get
end
