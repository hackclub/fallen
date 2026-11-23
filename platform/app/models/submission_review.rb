# One reviewer's decision on a Submission. There is a single review per submission, so it has to be complete:
# every rubric question answered, every journal given the time that counts (cut journal by journal, with a reason),
# an internal reason, and feedback for the person unless it is a clean approval. Approving funds the bill of materials
# as asked: every line is recorded as approved, and the reviewer returns the project to get a parts list changed.
# Rejecting is for good and only admins do it. Returning for changes needs none of the journal calls and applies none:
# the calls it was given are kept (JournalReview) for the next reviewer to start from, and the time and the funding are
# settled by the review that approves it.
#
# A project whose journals were written by AI is marked as such (`ai`) and can only be rejected for good, by any
# design reviewer: every journal it covers counts no time from then on, and the review needs nothing else but the
# internal reason and the feedback, which the page fills in from a template.
#
# Separately, the reviewer can take time off the project as a whole for staff only (`cut`, in minutes, as Fallout's
# hours_adjustment): it lowers Submission#internal_minutes, the hours reported to YSWS, and nothing the person sees.
#
# A design reviewer who isn't an admin doesn't send their decision: it is checked the same way, then held on the
# submission (`proposed_review`) for an admin to sign off (Admin::SignOffsController). Until then nothing applies, the
# person still sees it waiting, and it is out of the queue. Signing off saves it as the reviewer's decision, with a staff-only note naming
# the admin; neither can sign off a project they're on, and a proposer who has since lost the role can't be. Sending it
# back drops it and puts the submission back in the queue, with the reviewer's last draft to carry on from.
#
# Reviewers claim a submission while they work on it (claim), so two never review one at once; the page keeps the
# claim alive (heartbeat) and it lapses on its own after CLAIM_FOR.
class SubmissionReview
  include ActiveModel::Model

  CLAIM_FOR = 15.minutes
  VERDICTS = %w[approved returned rejected].freeze
  AI_CALL = { "approved_minutes" => 0, "reason" => JournalReview::AI_GENERATED }.freeze

  attr_reader :submission, :reviewer, :verdict, :feedback, :internal_reason, :rubric, :journals, :cut

  # The journals a review covers: every one with hours logged on the project before it was submitted.
  def self.journals_for(submission) = submission.project.journals.kept.where.not(duration_minutes: nil).where(created_at: ..submission.created_at)

  # The submission the reviewer should look at next: the one they hold, else the one waiting longest that isn't
  # their own team's, held by someone else, or skipped.
  def self.next_for(reviewer, skip: [])
    held = Submission.queued.find_by(claimed_by: reviewer, claim_expires_at: Time.current..)
    return held if held

    Submission.queued.where("claimed_by_id IS NULL OR claim_expires_at < ?", Time.current)
      .where.not(project_id: Project.teamed_with(reviewer).select(:id))
      .where.not(id: skip).order(:created_at, :id).first
  end

  # True if the reviewer now holds it. One UPDATE, so two reviewers opening it at once can't both win.
  def self.claim(submission, reviewer)
    Submission.queued.where(id: submission.id)
      .where("claimed_by_id IS NULL OR claimed_by_id = :id OR claim_expires_at < :now", id: reviewer.id, now: Time.current)
      .update_all(claimed_by_id: reviewer.id, claim_expires_at: CLAIM_FOR.from_now, updated_at: Time.current) == 1
  end

  # Takes a submission over from whoever holds it, for when they've walked away from an open tab. Their page finds out
  # on its next heartbeat and stops; what they had typed stays in their browser and its last save on the server.
  def self.take_over(submission, reviewer)
    Submission.queued.where(id: submission.id)
      .update_all(claimed_by_id: reviewer.id, claim_expires_at: CLAIM_FOR.from_now, updated_at: Time.current) == 1
  end

  # The held decision as an admin signs it off: the same review, made by the reviewer who proposed it. `proposed_at` is
  # the proposal the admin read (from the page, AdminSignOffSerializer): it applies only if that exact proposal is still
  # waiting when the lock is taken (`save`), so a send-back or a new proposal since the page loaded wins.
  def self.sign_off(submission, admin, proposed_at:)
    data = submission.proposed_review.to_h.symbolize_keys.slice(:verdict, :feedback, :internal_reason, :rubric, :journals, :ai, :cut)
    new(submission, reviewer: submission.proposed_by, signed_off_by: admin, signing_off: proposed_at, **data)
  end

  # Drops a held decision without applying it; the submission goes back in the queue.
  def self.send_back(submission, admin)
    submission.with_lock do
      return false unless submission.awaiting_sign_off?

      proposer = submission.proposed_by
      submission.update!(proposed_review: nil, proposed_at: nil, proposed_by: nil)
      submission.project.reviewer_notes.create!(submission:, user: admin,
        body: "Sent back to the queue instead of signing off #{proposer&.display_name || "a reviewer"}'s decision.")
    end
    true
  end

  # XP follows each journal's time that counts, preloaded so a big project is a few queries.
  def self.sync_xp(journals)
    journals = journals.reject(&:transferred?)
    ActiveRecord::Associations::Preloader.new(records: journals, associations: :xp_entry).call
    ActiveRecord::Associations::Preloader.new(records: journals.reject(&:xp_entry), associations: :user).call
    journals.each { XpEntry.sync(it) }
  end

  def self.release(submission, reviewer)
    Submission.where(id: submission.id, claimed_by_id: reviewer.id).update_all(claimed_by_id: nil, claim_expires_at: nil)
  end

  # Undoes a rejection, from a console, when it was a mistake:
  #   SubmissionReview.reopen(Submission.find_by_public_id!("sub_..."), by: User.find_by!(email: "you@hackclub.com"))
  # The submission goes back in the queue as it was sent, its journals count their logged time and XP again, its parts
  # lose their calls, and a reviewer note on the project keeps what the rejection said. Nobody is messaged.
  def self.reopen(submission, by:)
    journals = []
    submission.with_lock do
      raise ArgumentError, "#{submission.public_id} is #{submission.status}; only a rejected submission can be reopened" unless submission.rejected?

      submission.project.reviewer_notes.create!(submission:, user: by, body: <<~NOTE.truncate(2_000))
        Reopened. It was rejected#{" for AI-generated journals" if submission.ai_generated?} by #{submission.reviewer&.display_name || "a reviewer"} on #{submission.decided_at&.to_date&.to_fs(:long)}.
        Their reason: #{submission.internal_reason}
        Their feedback to the team: #{submission.feedback}
      NOTE
      reviews = submission.journal_reviews.includes(:journal).to_a
      journals = reviews.map(&:journal)
      reviews.each(&:destroy!)
      journals.each { it.update_column(:reviewed_minutes, nil) }
      submission.bom_items.update_all(verdict: nil, reason: nil, approved_cents: nil, updated_at: Time.current)
      submission.update!(status: "pending", reviewer: nil, decided_at: nil, rubric: {}, feedback: nil, internal_reason: nil,
        ai_generated: false, internal_deflated_minutes: nil)
    end
    sync_xp(journals)
    submission
  end

  def initialize(submission, reviewer:, verdict:, feedback: nil, internal_reason: nil, rubric: {}, journals: {}, ai: nil, cut: nil, signed_off_by: nil, signing_off: nil)
    @submission = submission
    @reviewer = reviewer
    @signed_off_by = signed_off_by
    @signing_off = signing_off
    @verdict = verdict.to_s
    @feedback = feedback.to_s.strip.presence
    @internal_reason = internal_reason.to_s.strip.presence
    @rubric = rubric.to_h.stringify_keys.slice(*Submission::RUBRIC.keys)
    @journals = journals.to_h.stringify_keys
    @ai = ActiveModel::Type::Boolean.new.cast(ai) || false
    @cut = cut.presence && Integer(cut.to_s, exception: false)
    @cut_given = cut.present?
  end

  def ai? = @ai
  # Held for an admin instead of applied (`propose`).
  def proposed? = @proposed || false
  def needs_sign_off? = !reviewer.admin? && @signed_off_by.nil?
  def returned? = verdict == "returned"
  def self.human_attribute_name(attribute, options = {})
    { "cut" => "Internal cut" }.fetch(attribute.to_s) { super }
  end

  def save
    covered = self.class.journals_for(submission).to_a
    items = submission.bom_items.to_a
    validate_decision(covered)
    return false if errors.any?
    return propose if needs_sign_off?

    submission.with_lock do
      next errors.add(:base, "Someone else already decided this") unless submission.pending?
      next errors.add(:base, "It's waiting for an admin to sign off") if submission.awaiting_sign_off? && @signed_off_by.nil?
      next errors.add(:base, "It was sent back or changed since you opened it") if @signed_off_by && !still_waiting?
      next errors.add(:base, "Someone else is reviewing this") if held_by_someone_else?

      @reviews = submission.journal_reviews.index_by(&:journal_id)
      if ai?
        # Every one, not just those whose time changed: a journal already cut to nothing may still hold XP.
        covered.each { |journal| record_journal(journal, AI_CALL) }
        self.class.sync_xp(covered)
      elsif returned?
        covered.each { |journal| record_journal(journal, journals[journal.public_id], apply: false) if usable_call?(journal) }
      else
        self.class.sync_xp(covered.select { |journal| record_journal(journal, journals.fetch(journal.public_id)) })
        items.each { it.update!(verdict: "approved", reason: nil, approved_cents: nil) } if verdict == "approved"
      end
      submission.update!(status: verdict, reviewer:, rubric:, feedback:, internal_reason:, decided_at: Time.current,
        ai_generated: ai?, internal_deflated_minutes: ai? || returned? ? nil : cut,
        approved_cents: verdict == "approved" ? items.sum(&:funded_cents) : nil, claimed_by: nil, claim_expires_at: nil,
        review_draft: nil, review_draft_at: nil, review_draft_by: nil, proposed_review: nil, proposed_at: nil, proposed_by: nil)
      GrantPayout.create!(submission:, user: submission.user, amount_cents: submission.approved_cents) if submission.approved? && submission.approved_cents.positive?
      if @signed_off_by
        submission.project.reviewer_notes.create!(submission:, user: @signed_off_by,
          body: "Checked and signed off #{reviewer.display_name}'s decision (#{verdict}).")
      end
    end
    return false if errors.any?

    # An approved design means the journals did their job: give back XP a journal review was holding (ProgressXpHold).
    ProgressXpHold.release_all(submission.project) if submission.approved?
    YswsSubmissionJob.perform_later(submission) if submission.approved?
    SubmissionDecidedJob.perform_later(submission)
    GrantPayoutJob.perform_later(submission.grant_payout) if submission.grant_payout && GrantPayout.automatic?
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.record.errors.full_messages.to_sentence)
    false
  end

  private

  def validate_decision(covered)
    validate_sign_off if @signed_off_by
    return if errors.any?

    errors.add(:verdict, "must be approve, return or reject") unless verdict.in?(VERDICTS)
    errors.add(:base, "You can't review a project you're on") if submission.project.on_team?(reviewer)
    errors.add(:internal_reason, "is needed: say why, for the next reviewer") if internal_reason.blank?
    errors.add(:feedback, "is needed so they know what to change") if feedback.blank? && verdict != "approved"
    if ai?
      errors.add(:base, "AI-generated journals can only be rejected for good") unless verdict == "rejected"
      return
    end

    errors.add(:base, "Only admins can reject") if verdict == "rejected" && !reviewer.admin?
    errors.add(:rubric, "needs every question answered") unless Submission::RUBRIC.keys.all? { |key| rubric[key].in?(Submission::ANSWERS) }
    return if returned?

    covered.each do |journal|
      problem = journal_problem(journal, journals[journal.public_id])
      errors.add(:journals, problem) if problem
    end
    validate_cut(covered) if errors[:journals].empty?
  end

  # The admin is vouching for a decision made by someone else, so both of them have to still be able to make it.
  def validate_sign_off
    if reviewer.nil? || reviewer.is_banned? || reviewer.discarded? || !reviewer.reviews_designs?
      errors.add(:base, "#{reviewer&.display_name || "Whoever proposed it"} is no longer a design reviewer: send it back")
    end
    errors.add(:base, "You can't sign off a project you're on") if submission.project.on_team?(@signed_off_by)
  end

  # The same proposal as when the admin opened it, still unapplied. `with_lock` has just reloaded the submission.
  def still_waiting? = @signing_off.present? && submission.awaiting_sign_off? && submission.proposed_at == @signing_off

  def validate_cut(covered)
    return unless @cut_given

    counted = covered.sum { Integer(journals.fetch(it.public_id)["approved_minutes"].to_s) }
    errors.add(:cut, "has to be a whole number of minutes, more than none and at most the #{counted} that count") unless cut&.between?(1, counted)
  end

  # Why a journal's call isn't a whole one, or nil when it is.
  def journal_problem(journal, call)
    return "each need a decision (#{journal.public_id} has none)" unless call

    minutes = Integer(call["approved_minutes"].to_s, exception: false)
    return "can't count more time than was logged" if minutes.nil? || minutes.negative? || minutes > journal.duration_minutes

    "need a reason when time is taken off" if minutes < journal.duration_minutes && !call["reason"].in?(JournalReview::REASONS)
  end

  def usable_call?(journal) = journal_problem(journal, journals[journal.public_id]).nil?

  # Holds the decision for an admin. The reviewer's draft stays, so a decision sent back can be picked up again.
  def propose
    submission.with_lock do
      next errors.add(:base, "Someone else already decided this") unless submission.pending? && !submission.awaiting_sign_off?
      next errors.add(:base, "Someone else is reviewing this") if held_by_someone_else?

      submission.update!(proposed_by: reviewer, proposed_at: Time.current, claimed_by: nil, claim_expires_at: nil, proposed_review: {
        "verdict" => verdict, "feedback" => feedback, "internal_reason" => internal_reason, "rubric" => rubric,
        "journals" => journals, "ai" => ai?, "cut" => @cut_given ? cut : nil
      })
      @proposed = true
    end
    errors.none?
  end

  def held_by_someone_else? = submission.claimed_by_id && submission.claimed_by_id != reviewer.id && submission.claim_expires_at&.future?

  # Keeps the call, and with `apply` makes it the time that counts. True when that time changed, so its XP has to follow.
  def record_journal(journal, call, apply: true)
    minutes = Integer(call["approved_minutes"].to_s)
    review = @reviews[journal.id] || submission.journal_reviews.build(journal:)
    review.update!(reviewer:, approved_minutes: minutes, reason: minutes < journal.duration_minutes ? call["reason"] : nil, note: call["note"].to_s.strip.presence)
    reviewed = minutes < journal.duration_minutes ? minutes : nil
    return false if !apply || journal.reviewed_minutes == reviewed

    journal.update_column(:reviewed_minutes, reviewed)
    true
  end
end
