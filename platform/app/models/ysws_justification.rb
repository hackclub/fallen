# frozen_string_literal: true

# The machine-written part of an approved design's hours justification for the YSWS Project Submission table
# (YswsSubmission's "Machine Justification"): how the time was logged and reviewed, every journal with its hours, what
# was cut and why, and who signed it off. It ends on the line that leads into the part staff write by hand in Airtable
# ("Manual Justification": why the hours fit Unified, and similar projects there).
module YswsJustification
  JOURNALING_RULES = "https://hwdocs.hackclub.dev/journaling/"

  module_function

  def render(submission, first_name:, commits: Github.commit_range(submission.repo_url, submission.commit_sha))
    project = submission.project
    journals = SubmissionReview.journals_for(submission).order(:created_at).includes(:lapse_timelapses).to_a
    calls = submission.journal_reviews.index_by(&:journal_id)
    rows = journals.map { |journal| Row.new(journal, calls[journal.id]&.approved_minutes || journal.reviewed_minutes || journal.duration_minutes) }
    claimed = rows.sum { it.journal.duration_minutes }
    approved = rows.sum(&:approved)
    cut = rows.reject { it.approved == it.journal.duration_minutes }
    timelapsed = rows.count { it.timelapses.any? }
    returns = project.submissions.where(status: "returned").where(created_at: ...submission.created_at).count
    signer = submission.signed_off_by || submission.reviewer
    second = signer && submission.reviewer && signer != submission.reviewer

    [
      "This is the design submission of \"#{project.title}\" for Fallen, submitted on #{moment(submission.created_at)}.",
      ("It was sent back #{returns} #{"time".pluralize(returns)} for changes before this version." if returns.positive?),
      [
        "#{first_name} logged their time in #{rows.size} #{"journal".pluralize(rows.size)}#{" between #{day(rows.first.journal.created_at)} and #{day(rows.last.journal.created_at)}" if rows.any?}, #{hours(claimed)} in total.",
        ("#{timelapsed} of those journals #{timelapsed == 1 ? "has a Lapse timelapse, which was" : "have a Lapse timelapse, each of which was"} audited thoroughly." if timelapsed.positive?),
        commits ? "The repository has commits from #{day(commits.first)} to #{day(commits.last)}: #{commits_url(submission.repo_url)}" : "The repository: #{submission.repo_url}"
      ].compact.join(" "),
      [
        "It was approved on #{moment(submission.decided_at)} by #{submission.reviewer&.display_name || "a reviewer"}, who read, audited and inspected every single journal against the repo and our journaling rules (#{JOURNALING_RULES}), and checked the design against what a finished, buildable project needs (#{url_helpers.docs_url(page: "submitting", host:)}).",
        ("It then went through a second sign-off by #{signer.display_name}." if second)
      ].compact.join(" "),
      "What was built:\n#{project.description.to_s.strip.presence || project.title}",
      "Journals:\n#{rows.map { journal_line(project, it) }.join("\n")}",
      [
        "#{hours(claimed)} logged, #{hours(approved)} approved.",
        ("#{hours(claimed - approved)} was deflated:\n#{cut.map { deflation_line(project, it, calls[it.journal.id]) }.join("\n")}" if cut.any?),
        ("On top of that, an internal deflation of #{hours(submission.internal_deflated_minutes)} brings the reported total to #{hours(submission.internal_minutes)}." if submission.internal_deflated_minutes.to_i.positive?)
      ].compact.join("\n"),
      ("#{first_name} said they used AI for: #{submission.ai_usage.strip}\nOur reviewers read their declaration and agreed that it is faithful." if submission.used_ai? && submission.ai_usage.present?),
      "The full review, journals and timelapses: #{url_helpers.review_submission_url(submission, host:)}",
      "This is signed off by Fallen staff member #{signer&.display_name.to_s.split.first || "a reviewer"}, and this is why they think #{hours(submission.internal_minutes).delete_suffix("h")} hours are appropriate for Unified:"
    ].compact.join("\n\n")
  end

  Row = Struct.new(:journal, :approved) do
    def timelapses = journal.lapse_timelapses.map(&:url).presence || [ journal.lapse_url ].compact_blank
  end

  def journal_line(project, row)
    journal = row.journal
    time = if journal.duration_minutes.to_i.zero? then "no time logged"
    elsif row.approved == journal.duration_minutes then "#{hours(row.approved)} approved in full"
    else "#{hours(journal.duration_minutes)} claimed, #{hours(row.approved)} approved"
    end
    lapse = ", timelapse: #{row.timelapses.join(", ")}" if row.timelapses.any?
    "- #{day(journal.created_at)}: #{journal_url(project, journal)} (#{time}#{lapse})"
  end

  def deflation_line(project, row, call)
    note = call&.note.to_s.strip.presence
    reason = call&.reason unless call&.reason == "Other" && note
    why = [ reason, note ].compact.join(": ").presence || "No reason recorded."
    "- #{day(row.journal.created_at)}: #{journal_url(project, row.journal)}, #{hours(row.journal.duration_minutes)} to #{hours(row.approved)}. #{why}"
  end

  def journal_url(project, journal) = "#{url_helpers.project_url(project, host:)}#journal-#{journal.public_id}"
  # Under 6 minutes would round to 0h, so it's given in minutes.
  def hours(minutes) = minutes.to_i.between?(1, 5) ? "#{minutes} min" : "#{(minutes.to_i / 60.0).round(1).to_s.delete_suffix(".0")}h"
  def day(time) = time.utc.strftime("%b %-d, %Y")
  def moment(time) = time ? time.utc.strftime("%B %-d, %Y at %H:%M UTC") : "an unknown date"
  def commits_url(repo_url) = "#{repo_url.to_s.delete_suffix("/").delete_suffix(".git")}/commits"
  def host = ENV.fetch("APP_URL", "http://localhost:3000")
  def url_helpers = Rails.application.routes.url_helpers
end
