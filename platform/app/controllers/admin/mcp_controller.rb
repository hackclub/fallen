# /admin/mcp: mint and revoke MCP tokens, and see what was done with them (docs/mcp.md). Minting answers JSON over
# the session, so the raw token is in that one response and never in flash (a cookie here), props or a log.
class Admin::McpController < Admin::ApplicationController
  ACTIONS_SHOWN = 50

  def index
    authorize McpAction, :index?, policy_class: Admin::McpPolicy
    tokens = policy_scope(AdminToken, policy_scope_class: Admin::McpPolicy::Scope).includes(:user).newest_first
    actions = policy_scope(McpAction, policy_scope_class: Admin::McpPolicy::Scope).includes(:user).newest_first.limit(ACTIONS_SHOWN)

    render inertia: "Admin/Mcp/Index", props: {
      tokens: AdminMcpTokenSerializer.render(tokens.to_a),
      actions: InertiaRails.defer { AdminMcpActionSerializer.render(actions.to_a) },
      mcp_url: mcp_url,
      max_lifetime_days: AdminToken::MAX_LIFETIME.in_days.to_i
    }
  end

  def create
    authorize AdminToken, :create?, policy_class: Admin::McpPolicy
    # A token outlives the session that minted it, so an admin browsing as someone else must not leave one behind.
    return render(json: { error: "You can't make a token while browsing as someone else." }, status: :forbidden) if impersonating?

    days = Integer(params[:lifetime_days].to_s, exception: false) || AdminToken::DEFAULT_LIFETIME.in_days.to_i
    unless days.between?(1, AdminToken::MAX_LIFETIME.in_days)
      return render(json: { error: "A token lasts 1 to #{AdminToken::MAX_LIFETIME.in_days.to_i} days." }, status: :unprocessable_content)
    end

    token = AdminToken.mint(user: true_user, name: params[:name], lifetime: days.days)
    Rails.logger.info({ event: "mcp_token.create", admin_id: true_user.id, token_id: token.id }.to_json)
    render json: { token: AdminMcpTokenSerializer.render(token), secret: token.token }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
  end

  def destroy
    token = policy_scope(AdminToken, policy_scope_class: Admin::McpPolicy::Scope).find(params[:id])
    authorize token, :destroy?, policy_class: Admin::McpPolicy
    token.revoke!
    Rails.logger.info({ event: "mcp_token.revoke", admin_id: true_user.id, token_id: token.id }.to_json)
    redirect_to admin_mcp_path, notice: "Revoked #{token.name}."
  end

  private

  def user_not_authorized
    return super unless action_name == "create"

    render json: { error: "You are not allowed to do that." }, status: :forbidden
  end
end
