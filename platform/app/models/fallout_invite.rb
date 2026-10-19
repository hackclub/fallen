# frozen_string_literal: true

# Fallout's emails link to /?email=…&code=… (FalloutLinksController) with the code Fallout's Airtable keeps for that
# email (verifyCode on its Users table), so a working link means the visitor got that email. Every email and code pair
# is copied here by SyncFalloutInvitesJob, so checking a link never waits on Airtable. Only an HMAC of each pair is
# kept: the code is six letters, so a plain hash would give it up in seconds, and there is no email kept for people
# who never come. Changing secret_key_base just means the next sync writes new ones.
# == Schema Information
#
# Table name: fallout_invites
#
#  digest :string           not null, primary key
#
class FalloutInvite < ApplicationRecord
  self.primary_key = :digest

  BASE = "appQgtRNTHxDGko9K"
  USERS_TABLE = "tblxIZLHdihXkmW86"
  EMAIL_FIELD = "fldclkJslUxjBquKC"
  CODE_FIELD = "flduf8V2BRdcNOhGZ"
  CODE = /\A[A-Z]{6}\z/

  def self.configured? = Airtable.configured?

  def self.match?(email, code)
    code = code.to_s.strip.upcase
    code.match?(CODE) && exists?(digest: digest(email, code))
  end

  # Replaces every pair at once, so a code gone from Fallout's Airtable stops working. Rows Fallout marked deleted are
  # kept: most are duplicates of a live row for the same email, and their code was emailed to that address all the same.
  def self.sync
    records = Airtable.records(BASE, USERS_TABLE, fields: [ EMAIL_FIELD, CODE_FIELD ])
    digests = records.filter_map { |fields| digest(fields[EMAIL_FIELD], fields[CODE_FIELD]) if fields[EMAIL_FIELD].present? && fields[CODE_FIELD].to_s.strip.upcase.match?(CODE) }.uniq
    raise Airtable::Error, "Fallout's Users table had no codes, so the old ones were kept" if digests.empty?

    transaction do
      delete_all
      digests.each_slice(1000) { |slice| insert_all!(slice.map { { digest: it } }) }
    end
    digests.size
  end

  def self.digest(email, code) = OpenSSL::HMAC.hexdigest("SHA256", key, "#{email.to_s.strip.downcase}\n#{code.to_s.strip.upcase}")

  def self.key = @key ||= Rails.application.key_generator.generate_key("fallout_invite", 32)
end
