# Design reviewers' decisions held for an admin (SubmissionReview#propose): sign one off to apply and send it, as it is or
# changed on the review page, or send it back to the queue.
class Admin::SignOffsController < Admin::ApplicationController
  def index
    authorize [ :admin, Submission ], :index?
    rows = policy_scope([ :admin, Submission ]).awaiting_sign_off.order(:proposed_at, :id)
    return render_desk(rows) if SignOffDesk.available?

    render inertia: "Admin/SignOffs/Index", props: {
      questions: Submission::RUBRIC,
      **deferred_table(rows.includes(:project, :user, :proposed_by), AdminSignOffSerializer, :submissions) { |records| { journals: journals_for(records) } }
    }
  end

  # Signs it off as proposed, or as the admin changed it on the review page (`review`, the same fields as
  # Review::SubmissionsController#update).
  def update
    submission = find_and_authorize
    edits = params[:review].present? ? params.expect(review: [ :verdict, :feedback, :internal_reason, :cut, :ai, rubric: {}, journals: {} ]).to_unsafe_h : nil
    review = SubmissionReview.sign_off(submission, true_user, proposed_at: read_proposal, edits:)
    if review.save
      # The desk shows its own confirmation, so only the review page and the plain list get a toast.
      notice = "#{submission.project.title}: #{submission.status} and sent." unless SignOffDesk.available? && !edits
      # From the review page: on to the next one, as in a review session. From the desk: the case it shows next.
      redirect_to edits ? review_next_sign_off_path(skip: params[:skip].to_s.split(",").grep(/\Asub_\w+\z/).first(50).join(",").presence) : admin_sign_offs_path(id: next_case), notice:
    elsif edits
      redirect_back fallback_location: review_submission_path(submission), inertia: { errors: review.errors.to_hash(true).transform_values(&:to_sentence) }
    else
      redirect_to admin_sign_offs_path(id: submission.public_id), alert: "#{submission.project.title}: #{review.errors.full_messages.to_sentence}"
    end
  end

  # An admin compared a copy check's match by hand (CopyCheck.compared!): not a copy unlocks approval.
  def compare
    submission = find_and_authorize
    copied = ActiveModel::Type::Boolean.new.cast(params[:copied]) || false
    CopyCheck.compared!(submission, true_user, copied:, note: params[:note].to_s.first(500))
    redirect_to admin_sign_offs_path(id: submission.public_id), notice: copied ? "Noted as copied. Return or reject it." : "Cleared. Approval is unlocked."
  rescue ArgumentError => e
    redirect_to admin_sign_offs_path(id: submission.public_id), alert: e.message
  end

  # Runs the copy check again, for a repo that changed since or a check that failed.
  def rescreen
    submission = find_and_authorize
    CopyCheck.rescreen(submission)
    redirect_to admin_sign_offs_path(id: submission.public_id), notice: "Checking it again."
  end

  def destroy
    submission = find_and_authorize
    if SubmissionReview.send_back(submission, true_user)
      redirect_to admin_sign_offs_path(id: next_case), notice: "#{submission.project.title}: back in the queue."
    else
      redirect_to admin_sign_offs_path(id: next_case), alert: "#{submission.project.title}: already signed off or sent back by someone else."
    end
  end

  private

  # The desk: the queue on the left, one decision on the right. `params[:id]` picks it, else the one waiting longest.
  # The case is its own deferred group, so moving through the queue reloads only that (`only: ['case']`).
  def render_desk(rows)
    render inertia: "Admin/SignOffs/Desk", props: {
      questions: Submission::RUBRIC,
      copy_check_available: CopyCheck.available?,
      **deferred_table(rows.includes(:project, :user, :proposed_by), SignOffRowSerializer, :queue),
      totals: InertiaRails.defer(group: "table") { totals(rows) },
      case: InertiaRails.defer(group: "case") { case_props(rows) }
    }
  end

  def case_props(rows)
    submission = rows.where_public_ids([ params[:id].to_s ]).first || rows.first
    return nil unless submission

    ActiveRecord::Associations::Preloader.new(records: [ submission ],
      associations: [ :user, :proposed_by, *(:copy_check_cleared_by if submission.copy_check_cleared_by_id), :bom_items, :project, { screenshots_attachments: :blob } ]).call
    Project.preload_teams([ submission.project ])
    returns = Submission.where(project_id: submission.project_id, status: "returned").count
    SignOffCaseSerializer.render(submission, journals: journals_for([ submission ], photos: true), returns: { submission.id => returns })
  end

  # How many wait and what approving them all would send, in one query.
  def totals(rows)
    count, cents = rows.reorder(nil).pick(Arel.sql("COUNT(*)"),
      Arel.sql("COALESCE(SUM(requested_cents) FILTER (WHERE proposed_review->>'verdict' = 'approved'), 0)"))
    { count:, approvals_cents: cents }
  end

  # The case the desk should land on after this one is dealt with, as the page asked for it.
  def next_case = params[:next].to_s[/\Asub_\w+\z/]

  # The journals each review covers (SubmissionReview.journals_for), in one query for the page.
  # `photos` also loads their uploads, for the desk, which shows each journal in full.
  def journals_for(records, photos: false)
    journals = Journal.kept.where(project_id: records.map(&:project_id)).where.not(duration_minutes: nil).order(:created_at, :id)
    journals = journals.includes(images_attachments: :blob) if photos
    journals = journals.group_by(&:project_id)
    records.to_h { |submission| [ submission.id, (journals[submission.project_id] || []).select { it.created_at <= submission.created_at } ] }
  end

  # The proposal the admin was looking at, at full precision (AdminSignOffSerializer). Missing or garbled reads as stale.
  def read_proposal = (Time.iso8601(params[:proposed_at].to_s) rescue nil)

  def find_and_authorize
    submission = Submission.find_by_public_id!(params[:id])
    authorize [ :admin, submission ]
    submission
  end
end
