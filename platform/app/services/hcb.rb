# HCB (https://hcb.hackclub.com), where design funding is sent from as card grants (GrantPayout). An admin connects
# the program's organization once (HcbAuthController), and its token is kept fresh by HcbTokenRefreshJob. Writes
# move real money, so outside production they only log unless HCB_ALLOW_WRITES is set.
module Hcb
  class Error < StandardError; end

  # restricted makes the token deny-by-default: it can only make and read card grants, nothing else on the org.
  SCOPES = "restricted card_grants:read card_grants:write".freeze
  # How long a new card grant stays spendable. Top-ups don't move it.
  GRANT_LIFETIME = 1.month

  module_function

  def host = ENV.fetch("HCB_HOST", "https://hcb.hackclub.com").chomp("/")
  def organization_id = ENV.fetch("HCB_ORGANIZATION_ID")
  def configured? = ENV["HCB_CLIENT_ID"].present? && ENV["HCB_CLIENT_SECRET"].present? && ENV["HCB_ORGANIZATION_ID"].present?
  def writes_allowed? = Rails.env.production? || ActiveModel::Type::Boolean.new.cast(ENV["HCB_ALLOW_WRITES"])

  def authorize_url(redirect_uri, state)
    params = { client_id: ENV.fetch("HCB_CLIENT_ID"), redirect_uri:, response_type: "code", scope: SCOPES, state: }
    "#{host}/api/v4/oauth/authorize?#{params.to_query}"
  end

  def exchange_code(code, redirect_uri) = token(grant_type: "authorization_code", code:, redirect_uri:)
  def refresh(refresh_token) = token(grant_type: "refresh_token", refresh_token:)

  def card_grant(id) = authed.get("/api/v4/card_grants/#{id}", { expand: "balance_cents" }).body

  def create_card_grant(amount_cents:, email:, purpose:)
    client = authed
    return stub(:create_card_grant, id: "cdg_stub#{SecureRandom.hex(4)}", email:, status: "active") unless writes_allowed?

    client.post("/api/v4/organizations/#{organization_id}/card_grants", { amount_cents:, email:, purpose:, expiration_at: GRANT_LIFETIME.from_now.to_date.iso8601 }.to_json, "Content-Type" => "application/json").body
  end

  def topup_card_grant(id, amount_cents:)
    client = authed
    return stub(:topup_card_grant, id:) unless writes_allowed?

    client.post("/api/v4/card_grants/#{id}/topup", { amount_cents: }.to_json, "Content-Type" => "application/json").body
  end

  def token(**params)
    connection.post("/api/v4/oauth/token", URI.encode_www_form(params.merge(client_id: ENV.fetch("HCB_CLIENT_ID"), client_secret: ENV.fetch("HCB_CLIENT_SECRET"))),
      "Content-Type" => "application/x-www-form-urlencoded").body
  end

  def stub(operation, **response)
    Rails.logger.warn("[Hcb] #{operation} skipped in #{Rails.env}: set HCB_ALLOW_WRITES=true to send for real")
    response
  end

  def connection
    Faraday.new(url: host, request: { timeout: 15, open_timeout: 5 }) do |f|
      f.response :json, parser_options: { symbolize_names: true }
      f.response :raise_error
    end
  end

  def authed
    access = HcbConnection.current&.usable_token or raise Error, "HCB isn't connected (or its token expired). Connect it on /admin/grants."
    connection.tap { |c| c.headers["Authorization"] = "Bearer #{access}" }
  end
end
