# Project transfers from the form linked on /transfers (ProjectTransfer), checked and decided by staff.
class Admin::TransfersController < Admin::ApplicationController
  TABS = %w[pending approved rejected all].freeze

  # Reviewers work transfers too; the route constraint and Admin::ProjectTransferPolicy decide who gets in.
  skip_before_action :require_admin!, only: %i[index show approve reject draft reach_out undo_reach_out refetch sync]
  before_action :require_transfer_reviewer!, only: %i[index show approve reject draft reach_out undo_reach_out refetch sync]

  def index
    tab = TABS.include?(params[:status]) ? params[:status] : "pending"
    scope = policy_scope([ :admin, ProjectTransfer ]).kept
    rows = (tab == "all" ? scope : scope.where(status: tab)).includes(:user, :reviewer, :reached_out_by).order(submitted_at: tab == "pending" ? :asc : :desc)

    render inertia: "Admin/Transfers/Index", props: {
      status: tab,
      # Reviewers who aren't admins can't open /admin/users, so their rows show the reviewer without a link.
      can: { sync: policy([ :admin, ProjectTransfer ]).sync?, view_users: true_user.admin? },
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
      direct_upload_url: uploads_path,
      can: { approve: policy.approve?, reject: policy.reject?, refetch: policy.refetch?, reach_out: policy.reach_out? }
    }
  end

  def approve
    transfer = find_and_authorize
    review = params.expect(transfer: [ :hours, :xp, :project_id, :note, :message, journals: [ [ :body, :date, images: [] ] ] ])
    project = Project.find_by_public_id!(review[:project_id]) if review[:project_id].present?

    if transfer.approve(reviewer: true_user, minutes: Duration.parse(review[:hours]), xp: review[:xp], project: project, note: review[:note], message: review[:message],
                        journals: review[:journals])
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

  # The note and message as they're typed, so a reviewer who leaves before deciding finds them again. Authorized as
  # reading it, since a refusal redirects (which autosave can't follow); the model refuses one already decided.
  # Answers with both as saved, so the page picks up what another reviewer wrote in the field this one didn't touch.
  def draft
    transfer = find_and_authorize(:show?)
    result = transfer.save_draft(params.expect(transfer: [ :note, :message ]), was: params.fetch(:was, {}).permit(:note, :message))
    render json: { result: result, **transfer.slice(:note, :message, :draft_saved_at) }, status: result == :saved ? :ok : :conflict
  end

  def reach_out
    transfer = find_and_authorize
    transfer.reach_out(by: true_user)
    redirect_back_or_to admin_transfers_path, notice: "Marked as reached out."
  end

  def undo_reach_out
    transfer = find_and_authorize
    transfer.undo_reach_out
    redirect_back_or_to admin_transfers_path, notice: "No longer marked as reached out."
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

  def require_transfer_reviewer!
    raise ActionController::RoutingError, "Not Found" unless current_user&.reviews_transfers?
  end

  def find_and_authorize(query = nil)
    ProjectTransfer.find_by_public_id!(params[:id]).tap { authorize [ :admin, it ], query }
  end
end
