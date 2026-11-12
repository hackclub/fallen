# Leaving a card grant in the HCB org out of the ledger when it isn't design funding (or counting it again).
class Admin::HcbGrantsController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #update authorizes explicitly

  def update
    grant = HcbOrgGrant.find_by!(hcb_id: params[:id])
    authorize [ :admin, grant ]
    ignore = ActiveModel::Type::Boolean.new.cast(params[:ignored])
    grant.update!(ignored_at: ignore ? Time.current : nil, ignored_by: ignore ? true_user : nil)
    redirect_back fallback_location: admin_grants_path(tab: "hcb"),
      notice: ignore ? "#{grant.hcb_id} no longer counts as design funding." : "#{grant.hcb_id} counts as design funding again."
  end
end
