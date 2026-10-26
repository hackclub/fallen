# Project transfers from the form linked on /transfers (ProjectTransfer), checked and decided by staff.
class Admin::TransfersController < Admin::ApplicationController
  TABS = %w[pending approved rejected all].freeze

  def index
    tab = TABS.include?(params[:status]) ? params[:status] : "pending"
    scope = policy_scope([ :admin, ProjectTransfer ]).kept
    rows = (tab == "all" ? scope : scope.where(status: tab)).includes(:user).order(submitted_at: tab == "pending" ? :asc : :desc)

    render inertia: "Admin/Transfers/Index", props: {
      status: tab,
      can: { sync: policy([ :admin, ProjectTransfer ]).sync? },
      counts: InertiaRails.defer(group: "table") { scope.group(:status).count },
      **deferred_table(rows, AdminProjectTransferSerializer, :transfers)
    }
  end

  def show
    transfer = ProjectTransfer.find_by_public_id!(params[:id])
    authorize [ :admin, transfer ]
    policy = policy([ :admin, transfer ])

    render inertia: "Admin/Transfers/Show", props: {
      transfer: AdminProjectTransferDetailSerializer.render(transfer),
      xp_per_hour: XpEntry::PER_HOUR,
      can: { approve: policy.approve?, reject: policy.reject?, refetch: policy.refetch? }
    }
  end

  def approve
    transfer = find_and_authorize
    review = params.expect(transfer: %i[hours xp project_id note message])
    project = Project.find_by_public_id!(review[:project_id]) if review[:project_id].present?

    if transfer.approve(reviewer: true_user, minutes: Duration.parse(review[:hours]), xp: review[:xp], project: project, note: review[:note], message: review[:message])
      redirect_to admin_transfer_path(transfer), notice: "Transfer approved: #{transfer.project.title} has the journals and #{transfer.xp} XP."
    else
      inertia_errors(transfer, fallback_location: admin_transfer_path(transfer))
    end
  end

  def reject
    transfer = find_and_authorize
    if transfer.reject(reviewer: true_user, note: params.dig(:transfer, :note), message: params.dig(:transfer, :message))
      redirect_to admin_transfers_path, notice: "Transfer rejected."
    else
      inertia_errors(transfer, fallback_location: admin_transfer_path(transfer))
    end
  end

  def refetch
    transfer = find_and_authorize
    FetchProjectTransferJob.perform_later(transfer)
    redirect_to admin_transfer_path(transfer), notice: "Fetching the project again. Reload in a moment."
  end

  def sync
    authorize [ :admin, ProjectTransfer ]
    SyncProjectTransfersJob.perform_later
    redirect_to admin_transfers_path, notice: "Pulling the form's rows from Airtable. Reload in a moment."
  end

  private

  def find_and_authorize
    ProjectTransfer.find_by_public_id!(params[:id]).tap { authorize [ :admin, it ] }
  end
end
