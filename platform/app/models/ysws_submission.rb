# frozen_string_literal: true

# An approved design as a row in the YSWS Project Submission table in Airtable, which Hack Club's YSWS staff use as
# the official record of what a program funded, as Fallout does (Ship#upload_to_unified_airtable!). The person's
# name, address and birthday come from Hack Club Auth when it is sent; the hours are Submission#internal_minutes, the
# time that counts less the reviewer's internal cut.
#
# Nothing is sent until AIRTABLE_YSWS_BASE_ID and AIRTABLE_YSWS_TABLE are set. Sending again updates the same row
# (Submission#ysws_airtable_id).
module YswsSubmission
  module_function

  def configured? = ENV["AIRTABLE_API_KEY"].present? && ENV["AIRTABLE_YSWS_BASE_ID"].present? && ENV["AIRTABLE_YSWS_TABLE"].present?

  def upload(submission)
    return unless configured? && submission.approved? && !submission.user.trial?

    id = Airtable.upsert(ENV.fetch("AIRTABLE_YSWS_BASE_ID"), ENV.fetch("AIRTABLE_YSWS_TABLE"), submission.ysws_airtable_id, fields(submission))
    submission.update_column(:ysws_airtable_id, id)
  end

  def fields(submission, identity: identity_of(submission.user))
    project = submission.project
    addresses = Array(identity["addresses"])
    address = addresses.find { it["primary"] } || addresses.first || {}
    screenshot = submission.screenshots.first
    {
      "Code URL" => submission.repo_url,
      "Playable URL" => project.demo_url.presence || submission.repo_url,
      "First Name" => identity["first_name"],
      "Last Name" => identity["last_name"],
      "Email" => submission.user.email,
      "Description" => project.description,
      "Address (Line 1)" => address["line_1"],
      "Address (Line 2)" => address["line_2"],
      "City" => address["city"],
      "State / Province" => address["state"],
      "Country" => address["country"],
      "ZIP / Postal Code" => address["postal_code"],
      "Birthday" => identity["birthday"],
      "Screenshot" => screenshot ? [ { url: url_helpers.rails_storage_proxy_url(screenshot, host:) } ] : [],
      "Optional - Override Hours Spent" => (submission.internal_minutes / 60.0).round(1),
      "Optional - Override Hours Spent Justification" => justification(submission)
    }
  end

  # The hours in words for whoever checks them: what was logged, what the review counted, the internal cut, and why.
  def justification(submission)
    count, logged, counted = SubmissionReview.journals_for(submission)
      .pick(Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(duration_minutes), 0)"), Arel.sql("COALESCE(SUM(COALESCE(reviewed_minutes, duration_minutes)), 0)"))
    [
      "#{Duration.format(logged)} logged across #{count} journals; #{Duration.format(counted)} counted by the design review.",
      ("Internal cut: #{Duration.format(submission.internal_deflated_minutes)}, so #{Duration.format(submission.internal_minutes)} reported." if submission.internal_deflated_minutes),
      "Reviewed by #{submission.reviewer&.display_name || 'a reviewer'} on #{submission.decided_at&.to_date&.to_fs(:long)}.",
      ("Reviewer's reason: #{submission.internal_reason}" if submission.internal_reason.present?),
      "Review: #{url_helpers.review_submission_url(submission, host:)}"
    ].compact.join("\n")
  end

  # As Fallout does: a fetch that fails is reported and the row goes without the person's details, for staff to fill.
  def identity_of(user)
    user.hca_token.present? ? HCA.identity(user.hca_token) : {}
  rescue StandardError => e
    Rails.error.report(e, handled: true, context: { ysws_submission: { user: user.public_id } })
    {}
  end
  def host = ENV.fetch("APP_URL", "http://localhost:3000")
  def url_helpers = Rails.application.routes.url_helpers
end
