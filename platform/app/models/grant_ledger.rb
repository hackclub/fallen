# Compares what HCB says each person has been given with what Fallen has sent them. HCB has no idempotency keys, so a
# repeated request is a second payment; this is what catches it. Every send checks first (GrantPayout#send!), a failed
# send is settled from HCB's numbers rather than someone's reading of HCB (GrantPayout#check_hcb!), and
# GrantLedgerSyncJob re-checks everyone every few minutes for /admin/grants.
module GrantLedger
  class Mismatch < StandardError; end

  # A card this close to expiring isn't topped up: HCB would hand the money back to the org within days.
  TOP_UP_MARGIN = 3.days
  # A send this recent may still be waiting on HCB, so "Check HCB" leaves it alone.
  SENDING_GRACE = 2.minutes

  module_function

  # Copies every card grant in the org from HCB, matched to people by the card Fallen made, a payout marked sent with
  # that grant's id, or email.
  def sync!
    grants = Hcb.org_card_grants
    now = Time.current
    ids = grants.pluck(:id)
    owners = GrantPayout.where(hcb_reference: ids).pluck(:hcb_reference, :user_id).to_h.merge(HcbGrantCard.where(hcb_id: ids).pluck(:hcb_id, :user_id).to_h)
    emails = grants.map { normalize(it[:email]) }.uniq
    people = User.where("LOWER(email) IN (?)", emails).pluck(:email, :id).to_h { |email, id| [ normalize(email), id ] }

    rows = grants.map do |grant|
      { hcb_id: grant[:id], email: normalize(grant[:email]), user_id: owners[grant[:id]] || people[normalize(grant[:email])],
        amount_cents: grant[:amount_cents].to_i, balance_cents: grant[:balance_cents], status: grant[:status].to_s,
        expires_on: grant[:expires_on], purpose: grant[:purpose], synced_at: now, created_at: now, updated_at: now }
    end
    HcbOrgGrant.upsert_all(rows, unique_by: :hcb_id, update_only: %i[email user_id amount_cents balance_cents status expires_on purpose synced_at]) if rows.any?
    retire_cards(grants)
    HcbConnection.current&.update_columns(ledger_checked_at: now, ledger_error: nil)
  rescue Faraday::Error => e
    HcbConnection.current&.update_columns(ledger_error: "#{e.class}: #{e.message.truncate(300)}")
    raise Hcb::Error, "Couldn't read HCB's card grants (#{e.message.truncate(200)})"
  end

  # Before a send: HCB and Fallen must agree on everything this person has been sent so far.
  def check!(user)
    return unless Hcb.writes_allowed? # Stubbed sends never reach HCB, so there is nothing to compare.

    sync!
    paid, sent = paid_cents(user), sent_cents(user)
    return if paid == sent

    raise Mismatch, "Not sent: HCB shows #{Money.format(paid)} given to #{user.email}, Fallen has sent #{Money.format(sent)}. " \
      "Find the difference on /admin/grants (On HCB) before sending more."
  end

  def paid_cents(user) = HcbOrgGrant.counted.where(user:).sum(:amount_cents)
  def sent_cents(user) = GrantPayout.where(user:, status: "sent").sum(:amount_cents)

  # Everyone whose HCB total differs from what Fallen sent up to the last sync, as { user_id => [hcb, fallen] }.
  # Two grouped queries, sized by the number of people ever paid.
  def mismatches(checked_at)
    return {} unless checked_at

    paid = HcbOrgGrant.counted.where.not(user_id: nil).group(:user_id).sum(:amount_cents)
    sent = GrantPayout.where(status: "sent", sent_at: ..checked_at).group(:user_id).sum(:amount_cents)
    (paid.keys | sent.keys).filter_map { |id| [ id, [ paid[id].to_i, sent[id].to_i ] ] if paid[id].to_i != sent[id].to_i }.to_h
  end

  def normalize(email) = email.to_s.strip.downcase

  # Cards HCB has expired or canceled are never topped up again (HCB refuses it anyway).
  def retire_cards(grants)
    grants.each do |grant|
      next if grant[:status].to_s == "active"

      HcbGrantCard.active.where(hcb_id: grant[:id]).find_each { it.update!(status: grant[:status].to_s.presence_in(%w[canceled expired]) || "canceled") }
    end
  end
end
