# The approval page for a write an MCP agent asked for with query_sql (McpSqlChange, docs/mcp.md): the SQL, who asked,
# and a preview of every row it touches, with Approve and Reject. Only a signed-in admin's session reaches it.
class Admin::SqlChangesController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized

  before_action :set_change

  def show
    render inertia: "Admin/SqlChanges/Show", props: { change: AdminSqlChangeDetailSerializer.render(@change) }
  end

  def update
    case params.expect(:decision)
    when "approve" then @change.approve!(true_user)
    when "reject" then @change.reject!(true_user)
    else raise ActionController::BadRequest, "decision must be approve or reject"
    end
    redirect_to admin_sql_change_path(@change), **flash_for(@change)
  rescue Mcp::Refused => e
    redirect_to admin_sql_change_path(@change), alert: e.message
  end

  private

  def set_change
    # The page reads who asked, who decided and the token's name; deciding reads only the token.
    @change = (action_name == "show" ? McpSqlChange.includes(:user, :reviewer, :admin_token) : McpSqlChange).find_by_public_id!(params[:id])
    authorize @change, (action_name == "show" ? :show? : :update?), policy_class: Admin::SqlChangePolicy
  end

  def flash_for(change)
    case change.status
    when "done" then { notice: "Done. #{helpers.pluralize(change.rows_affected, 'row')} changed." }
    when "failed" then { alert: "Nothing was changed: #{change.error}" }
    else { notice: "Rejected. Nothing was changed." }
    end
  end
end
