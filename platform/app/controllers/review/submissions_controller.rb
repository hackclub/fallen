# The design review queue and the page a submission is reviewed on (SubmissionReview).
class Review::SubmissionsController < Review::ApplicationController
  include DeferredTable

  TABS = %w[queue sign_off mine decided flagged].freeze

  def index
    tab = TABS.include?(params[:tab]) ? params[:tab] : "queue"
    scope = policy_scope([ :review, Submission ]).where.not(status: "withdrawn")
    rows = case tab
    when "queue" then scope.queued.order(:created_at, :id)
    when "sign_off" then scope.awaiting_sign_off.order(:proposed_at, :id)
    when "mine" then scope.decided.where(reviewer: true_user).order(decided_at: :desc)
    when "decided" then scope.decided.order(decided_at: :desc)
    else scope.pending.where.not(flagged_at: nil).order(:created_at)
    end

    render inertia: "Review/Submissions/Index", props: {
      tab:,
      counts: InertiaRails.defer(group: "table") { queue_counts(scope) },
      **deferred_table(rows.includes(:project, :user, :reviewer, :claimed_by, :proposed_by), ReviewQueueRowSerializer, :submissions) do |records|
        { resubmitted: Submission.where(project_id: records.map(&:project_id), status: "returned").distinct.pluck(:project_id).to_set }
      end
    }
  end

  # Claims the next submission for the reviewer and opens it. `skip` lists ones they passed over this session.
  def next
    authorize [ :review, Submission ]
    skip = skipped
    submission = SubmissionReview.next_for(true_user, skip: Submission.where(id: skip.filter_map { |id| Submission.find_by_public_id(id)&.id }))
    return redirect_to(review_submissions_path, notice: "Nothing left in the queue. Nice work!") unless submission

    SubmissionReview.claim(submission, true_user)
    redirect_to review_submission_path(submission, skip: skip.join(",").presence)
  end

  # The same, over design reviewers' decisions waiting for an admin to sign them off.
  def next_sign_off
    authorize [ :review, Submission ]
    skip = skipped
    submission = SubmissionReview.next_for(true_user, signing_off: true, skip: Submission.where(id: skip.filter_map { |id| Submission.find_by_public_id(id)&.id }))
    return redirect_to(admin_sign_offs_path, notice: "Nothing left to sign off. Nice work!") unless submission

    SubmissionReview.claim(submission, true_user)
    redirect_to review_submission_path(submission, skip: skip.join(",").presence)
  end

  def show
    submission = find_submission
    authorize [ :review, submission ]
    claimed = policy([ :review, submission ]).claim? && SubmissionReview.claim(submission, true_user)
    submission.reload if claimed

    policy = policy([ :review, submission ])
    # An admin signing off a held decision works it like any review and sends it to Admin::SignOffsController.
    sign_off = policy.sign_off?
    can = { decide: policy.claim? && claimed, sign_off:, take_over: policy.claim? && !claimed, reject: policy.reject? || sign_off,
            cut: policy.cut?, flag: policy.flag?, unflag: policy.unflag?, note: policy.note? }
    render inertia: "Review/Submissions/Show", props: ReviewPageProps.new(submission, reviewer: true_user, claimed:, can:).props.merge(skip: skipped.join(","))
  end

  def update
    submission = find_submission
    authorize [ :review, submission ], :decide?
    # Any design reviewer can reject a project for AI-generated journals (SubmissionReview); anything else only admins.
    ai = ActiveModel::Type::Boolean.new.cast(params.dig(:review, :ai))
    raise Pundit::NotAuthorizedError if params.dig(:review, :verdict) == "rejected" && !ai && !policy([ :review, submission ]).reject?
    raise Pundit::NotAuthorizedError if params.dig(:review, :cut).present? && !policy([ :review, submission ]).cut?

    fields = params.expect(review: [ :verdict, :feedback, :internal_reason, :cut, :ai, rubric: {}, journals: {} ])
    review = SubmissionReview.new(submission, reviewer: true_user, verdict: fields[:verdict], feedback: fields[:feedback], internal_reason: fields[:internal_reason],
      rubric: fields[:rubric]&.to_unsafe_h, journals: fields[:journals]&.to_unsafe_h, ai: fields[:ai], cut: fields[:cut])
    if review.save
      notice = review.proposed? ? "#{submission.project.title}: sent to an admin to sign off." : "#{submission.project.title}: #{submission.status}."
      redirect_to review_next_path(skip: skipped.join(",").presence), notice:
    else
      redirect_back fallback_location: review_submission_path(submission), inertia: { errors: review.errors.to_hash(true).transform_values(&:to_sentence) }
    end
  end

  def heartbeat
    submission = find_submission
    authorize [ :review, submission ], :claim?
    # A page opened to sign off doesn't quietly pick up the submission as a fresh review once it's sent back.
    signing_off = ActiveModel::Type::Boolean.new.cast(params[:sign_off]) || false
    render json: { held: submission.awaiting_sign_off? == signing_off && SubmissionReview.claim(submission, true_user) }
  end

  # The review so far, saved as the reviewer works and when they leave the page (lib/review.svelte.ts).
  def draft
    submission = find_submission
    # Only a review being written: an admin's changes to a held decision stay in their browser, so the reviewer's
    # own draft is still there if it's sent back.
    authorize [ :review, submission ], :decide?
    data = params.expect(draft: {})&.to_unsafe_h
    if submission.save_review_draft(true_user, data)
      render json: { saved: true }
    else
      render json: { saved: false }, status: :conflict
    end
  end

  def take_over
    submission = find_submission
    authorize [ :review, submission ], :claim?
    SubmissionReview.take_over(submission, true_user)
    redirect_to review_submission_path(submission, skip: skipped.join(",").presence), notice: "It's yours now."
  end

  # Skip: lets go of it and opens the next one.
  def release
    submission = find_submission
    authorize [ :review, submission ], :show?
    SubmissionReview.release(submission, true_user)
    skip = [ *skipped, submission.public_id ].uniq.join(",")
    redirect_to submission.awaiting_sign_off? ? review_next_sign_off_path(skip:) : review_next_path(skip:)
  end

  def flag
    submission = find_submission
    authorize [ :review, submission ]
    reason = params.expect(:reason).to_s.strip
    return redirect_back(fallback_location: review_submission_path(submission), alert: "Say why it's flagged") if reason.blank?

    submission.update!(flagged_at: Time.current, flag_reason: reason, claimed_by: nil, claim_expires_at: nil)
    submission.project.reviewer_notes.create!(submission:, user: true_user, body: "Flagged for fraud: #{reason}")
    redirect_to review_next_path(skip: skipped.join(",").presence), notice: "Flagged. It's out of the queue until an admin looks at it."
  end

  def unflag
    submission = find_submission
    authorize [ :review, submission ]
    submission.update!(flagged_at: nil, flag_reason: nil)
    submission.project.reviewer_notes.create!(submission:, user: true_user, body: "Fraud flag cleared")
    redirect_to review_submission_path(submission), notice: "Back in the queue."
  end

  private

  def find_submission = Submission.find_by_public_id!(params[:id])
  def skipped = params[:skip].to_s.split(",").grep(/\Asub_\w+\z/).first(50)

  def queue_counts(scope)
    { queue: scope.queued.count, sign_off: scope.awaiting_sign_off.count, flagged: scope.pending.where.not(flagged_at: nil).count, mine: scope.decided.where(reviewer: true_user).count,
      decided: scope.decided.count, oldest: scope.queued.minimum(:created_at) }
  end
end
