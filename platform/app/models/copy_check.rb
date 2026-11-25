# frozen_string_literal: true

# A check of a design's files against public repositories for copies, kept on Submission#copy_check. The checker
# (CopyChecker) lives in the private hackclub/fallen-desk repo, mounted at vendor/desk; without it nothing is checked.
#
# A result has a status (pending, match, clear, unscreenable or failed), a reason when there is more to say, and the
# repositories it matched. A match is a reason for a person to compare the two designs, never a decision: it blocks
# approval at sign-off until an admin has compared them (Submission#copy_check_holds_approval?). It runs when a
# reviewer's decision is held for sign-off (SubmissionReview#propose), and CopyCheckSweepJob retries what is pending.
module CopyCheck
  STATUSES = %w[pending match clear unscreenable failed].freeze

  module_function

  def available? = defined?(::CopyChecker) && ::CopyChecker.configured?

  def later(submission)
    CopyCheckJob.perform_later(submission) if available?
  end

  def run(submission)
    return unless available?

    state = submission.copy_check || {}
    return unless state.empty? || state["status"] == "pending"

    result = ::CopyChecker.check(submission.repo_url, attempts: state["attempts"].to_i)
    unless result["status"].in?(%w[pending failed])
      others = same_repo(submission)
      result = result.merge("same_repo" => others)
      # Another team sending the same repository is a match too, with no other repository to compare.
      result = result.merge("status" => "match", "reason" => "same_repo") if others.any? && result["status"] != "match"
    end
    submission.update!(copy_check: result)
  end

  # Clears the result so it is checked again, for a repo that changed or a check that failed.
  def rescreen(submission)
    submission.update!(copy_check: { "status" => "pending", "attempts" => 0 }, copy_check_cleared_by: nil, copy_check_cleared_at: nil)
    later(submission)
  end

  # An admin compared a match by hand. `copied: false` unlocks approval; either way the project's reviewer notes keep
  # what they found, for whoever looks next.
  def compared!(submission, admin, copied:, note: nil)
    submission.with_lock do
      raise ArgumentError, "Only a match can be compared" unless submission.copy_check&.dig("status") == "match"

      compared = { "copied" => copied, "by" => admin.display_name, "at" => Time.current.iso8601 }
      submission.update!(copy_check: submission.copy_check.merge("compared" => compared),
        copy_check_cleared_by: (copied ? nil : admin), copy_check_cleared_at: (copied ? nil : Time.current))
      repos = Array(submission.copy_check["matches"]).map { it["repo"] }.presence || Array(submission.copy_check["same_repo"]).map { it["title"] }
      body = "Compared the design with #{repos.to_sentence}: #{copied ? 'it is copied' : 'not a copy'}."
      body += " #{note.to_s.strip}" if note.present?
      submission.project.reviewer_notes.create!(submission:, user: admin, body: body.truncate(2_000))
    end
  end

  # Other Fallen projects whose submissions point at the same GitHub repository.
  def same_repo(submission)
    repo = submission.repo_url.to_s[%r{\Ahttps?://(?:www\.)?github\.com/([^/]+/[^/#?]+)}i, 1]&.delete_suffix(".git")
    return [] unless repo

    pattern = "^https?://(www\\.)?github\\.com/#{Regexp.escape(repo)}(\\.git)?(/.*)?$"
    Project.joins(:submissions).where.not(id: submission.project_id).where("submissions.repo_url ~* ?", pattern)
      .distinct.limit(5).select(:id, :title).map { { "project" => it.public_id, "title" => it.title } }
  end
end
