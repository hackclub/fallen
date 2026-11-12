# frozen_string_literal: true

# One card grant in the HCB org, for /admin/grants (On HCB). `mismatches` is GrantLedger.mismatches, so each row says
# whether its person's HCB total disagrees with what Fallen sent them.
class AdminHcbOrgGrantSerializer < ApplicationSerializer
  typelize_from HcbOrgGrant
  typelize id: :string, url: :string, person: "{ id: string; name: string; avatar: string } | null",
           ignored: :boolean, ignored_by: "{ id: string; name: string; avatar: string } | null",
           ledger: "{ hcb_cents: number; fallen_cents: number } | null"
  attributes :email, :amount_cents, :balance_cents, :status, :expires_on, :purpose, :synced_at
  attribute(:id, &:hcb_id)
  attribute(:url, &:hcb_url)
  attribute(:ignored, &:ignored?)
  one :user, key: :person, resource: PersonSerializer
  one :ignored_by, resource: PersonSerializer
  attribute(:ledger) do |grant|
    hcb, fallen = params[:mismatches]&.dig(grant.user_id)
    hcb && { hcb_cents: hcb, fallen_cents: fallen }
  end
end
