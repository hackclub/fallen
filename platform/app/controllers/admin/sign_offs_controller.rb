# Design reviewers' decisions held for an admin (SubmissionReview#propose): sign one off to apply and send it, as it is or
# changed on the review page, or send it back to the queue.
class Admin::SignOffsController < Admin::ApplicationController
  def index
    authorize [ :admin, Submission ], :index?
    rows = policy_scope([ :admin, Submission ]).awaiting_sign_off.order(:proposed_at, :id)

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
      notice = "#{submission.project.title}: #{submission.status} and sent."
      # From the review page: on to the next one, as in a review session.
      redirect_to edits ? review_next_sign_off_path(skip: params[:skip].to_s.split(",").grep(/\Asub_\w+\z/).first(50).join(",").presence) : admin_sign_offs_path, notice:
    elsif edits
      redirect_back fallback_location: review_submission_path(submission), inertia: { errors: review.errors.to_hash(true).transform_values(&:to_sentence) }
    else
      redirect_to admin_sign_offs_path, alert: "#{submission.project.title}: #{review.errors.full_messages.to_sentence}"
    end
  end

  def destroy
    submission = find_and_authorize
    if SubmissionReview.send_back(submission, true_user)
      redirect_to admin_sign_offs_path, notice: "#{submission.project.title}: back in the queue."
    else
      redirect_to admin_sign_offs_path, alert: "#{submission.project.title}: already signed off or sent back by someone else."
    end
  end

  private

  # The journals each review covers (SubmissionReview.journals_for), in one query for the page.
  def journals_for(records)
    journals = Journal.kept.where(project_id: records.map(&:project_id)).where.not(duration_minutes: nil).order(:created_at, :id).group_by(&:project_id)
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
