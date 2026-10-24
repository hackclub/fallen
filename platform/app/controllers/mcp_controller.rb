# The admin MCP server (docs/mcp.md): an MCP client speaks JSON-RPC to POST /mcp with an AdminToken as its Bearer
# header, and the tools are the admin panel's own actions (Mcp::Registry). The gem's transport is built fresh for every
# request and keeps no session, so nothing lives between calls but the rows Mcp::Invoke writes.
#
# ActionController::API, so no session cookie is read: only the token authenticates, and a page on another site can't
# make a browser send one. Refusals say nothing about why a token failed.
class McpController < ActionController::API
  MAX_REQUEST_BYTES = 256.kilobytes

  before_action :authenticate!, only: :handle

  def handle
    server = MCP::Server.new(
      name: "fallen-admin", title: "Fallen admin", version: "1",
      instructions: Mcp::Registry::INSTRUCTIONS, tools: Mcp::Registry.tools,
      # Production only answers APP_HOST (config.hosts), so the base URL can't be pointed elsewhere.
      server_context: { admin: @admin, token: @token, base_url: request.base_url }
    )
    # The Host and Origin checks are for unauthenticated local servers; a browser can't attach the Bearer header
    # cross-site, and Orchard's proxy owns the Host header. JSON responses because a Rails action buffers its body.
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      server, stateless: true, enable_json_response: true, serve_subscriptions_listen: false,
      dns_rebinding_protection: false, max_request_bytes: MAX_REQUEST_BYTES
    )
    status, headers, body = transport.handle_request(request)
    response.headers.merge!(headers.except("content-type", "content-length"))
    # A notification (notifications/initialized) gets an empty 202; `render json: nil` would send "null".
    return head(status) if body.blank?

    render json: body.first, status: status
  end

  def not_allowed
    response.headers["Allow"] = "POST"
    render json: { error: "method_not_allowed" }, status: :method_not_allowed
  end

  private

  def authenticate!
    response.headers["Cache-Control"] = "no-store"
    return render(json: { error: "mcp_disabled" }, status: :service_unavailable) if Flipper.enabled?(:disable_admin_mcp)

    token = AdminToken.authenticate(request.authorization.to_s[/\ABearer (\S+)\z/, 1])
    # The role is checked on every call, so a demoted, banned or deleted admin's token stops working at once even
    # if revoking it somehow failed.
    admin = token && User.kept.find_by(id: token.user_id)
    unless admin&.admin? && !admin.is_banned?
      response.headers["WWW-Authenticate"] = 'Bearer realm="fallen-admin"'
      return render(json: { error: "unauthorized" }, status: :unauthorized)
    end

    token.touch_used!
    @admin = admin
    @token = token
  end
end
