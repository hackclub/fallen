# frozen_string_literal: true

# An approved design as a row in the YSWS Project Submission table in Airtable, which Hack Club's YSWS staff use as
# the official record of what a program funded, as Fallout does (Ship#upload_to_unified_airtable!). The person's
# name, address and birthday come from Hack Club Auth when it is sent; the hours are Submission#internal_minutes, the
# time that counts less the reviewer's internal cut. The justification goes in "Machine Justification" (YswsJustification);
# staff add their own in "Manual Justification", and the table joins the two into the field YSWS reads.
#
# Nothing is sent until AIRTABLE_YSWS_BASE_ID and AIRTABLE_YSWS_TABLE are set. Sending again updates the same row
# (Submission#ysws_airtable_id).
module YswsSubmission
  module_function

  OVERRIDE = "Optional - Override Hours Spent Justification"
  MACHINE = "Machine Justification"
  MANUAL = "Manual Justification"
  SIGN_OFF = "Sign-off Override"

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
      MACHINE => YswsJustification.render(submission, first_name: identity["first_name"].to_s.strip.presence || submission.user.display_name.split.first)
    }
  end

  # The field YSWS reads is managed by Hack Club's org and can't be a formula, so this fills it: the machine part, then
  # what staff wrote by hand. Only rows Fallen wrote, and only those that changed, so running it again does nothing.
  def join_justifications
    return 0 unless configured?

    base, table = ENV.fetch("AIRTABLE_YSWS_BASE_ID"), ENV.fetch("AIRTABLE_YSWS_TABLE")
    rows = Airtable.records(base, table, fields: [ MACHINE, MANUAL, OVERRIDE, SIGN_OFF ], whole: true, by_name: true)
    rows.count do |row|
      fields = row["fields"]
      next false if fields[MACHINE].blank?

      joined = joined_justification(fields[MACHINE], fields[MANUAL], sign_off: fields[SIGN_OFF])
      next false if fields[OVERRIDE].to_s.strip == joined

      Airtable.upsert(base, table, row["id"], OVERRIDE => joined)
      sleep 0.25
      true
    end
  end

  # `sign_off` (Sign-off Override) names someone else as the staff member who signed it off, in both places
  # YswsJustification names them.
  def joined_justification(machine, manual, sign_off: nil)
    machine = machine.to_s.strip
    if (name = sign_off.to_s.strip.presence)
      machine = machine.sub(/(It then went through a second sign-off by ).+\.$/) { "#{$1}#{name}." }
        .sub(/^(This is signed off by Fallen staff member ).+?(, and this is why)/) { "#{$1}#{name}#{$2}" }
    end
    [ machine, manual.to_s.strip ].compact_blank.join("\n\n")
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
