# frozen_string_literal: true

# Verifies tokens from the Hack Club privacy hub (https://yeet.hackclub.com/docs/deletions).
# Keys come from the hub's JWKS, cached for five minutes and refetched (at most every 30 seconds) when a token
# names a kid we have not seen. PRIVACY_JWKS_URL overrides the JWKS location.
module PrivacyToken
  AUDIENCE = "fallen"
  ISSUER = "hackclub-privacy"
  LEEWAY = 30
  MAX_LIFETIME = 300
  KEYS_TTL = 5.minutes
  KEYS_REFETCH_AFTER = 30.seconds
  DEFAULT_JWKS_URL = "https://yeet.hackclub.com/.well-known/jwks.json"
  REQUIRED_CLAIMS = %w[iss aud iat exp jti request_id action dry_run subject].freeze

  class Invalid < StandardError; end
  class ActionMismatch < StandardError; end
  class KeysUnavailable < StandardError; end

  MUTEX = Mutex.new

  module_function

  # Returns the verified claims, or raises Invalid, ActionMismatch or KeysUnavailable.
  def verify!(token, action:)
    raise Invalid, "missing token" if token.blank?

    claims, header = JWT.decode(token, nil, true,
      algorithms: [ "ES256" ],
      jwks: method(:keys),
      iss: ISSUER, verify_iss: true,
      aud: AUDIENCE, verify_aud: true,
      verify_iat: { leeway: LEEWAY },
      leeway: LEEWAY,
      required_claims: REQUIRED_CLAIMS)

    raise Invalid, "typ" unless header["typ"] == "JWT"
    raise Invalid, "lifetime" unless claims["iat"].is_a?(Integer) && claims["exp"].is_a?(Integer) && claims["exp"] - claims["iat"] <= MAX_LIFETIME
    raise Invalid, "claims" unless claims["jti"].is_a?(String) && claims["request_id"].is_a?(String) && claims["subject"].is_a?(Hash) && [ true, false ].include?(claims["dry_run"])
    raise ActionMismatch unless claims["action"] == action

    claims
  rescue JWT::DecodeError => e
    raise Invalid, e.class.name
  end

  def jwks_url = ENV["PRIVACY_JWKS_URL"].presence || DEFAULT_JWKS_URL

  def keys(options = {})
    MUTEX.synchronize do
      stale = @keys.nil? || @keys_fetched_at < KEYS_TTL.ago
      unknown_kid = options[:kid_not_found] && @keys_fetched_at < KEYS_REFETCH_AFTER.ago
      if stale || unknown_kid
        @keys = fetch_jwks
        @keys_fetched_at = Time.current
      end
      @keys
    end
  end

  def fetch_jwks
    response = Faraday.new { |f| f.options.timeout = 5 }.get(jwks_url)
    raise KeysUnavailable, "JWKS returned #{response.status}" unless response.success?

    JSON.parse(response.body).tap { |jwks| raise KeysUnavailable, "JWKS has no keys" unless jwks.is_a?(Hash) && jwks["keys"].is_a?(Array) }
  rescue Faraday::Error, JSON::ParserError => e
    raise KeysUnavailable, e.class.name
  end
end
