# The funding an approved design submission earns, sent to the person who submitted it as an HCB card grant: their
# first one makes the card, later ones top it up. With the hcb_auto_grants flag on, GrantPayoutJob sends it as soon
# as the review is in; otherwise (or when sending fails) an admin sends it on HCB and marks it here (/admin/grants).
#
# Sending is "at most once": the row is marked "sending" and committed before HCB is called, so a crash or a timeout
# mid-call leaves it failed, never sent twice. Before calling HCB it checks that HCB's total for the person matches what
# Fallen has sent (GrantLedger), and a failed one is settled from HCB's numbers by check_hcb!, not by someone's eye.
# == Schema Information
#
# Table name: grant_payouts
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer          not null
#  error             :text
#  hcb_reference     :string
#  sent_at           :datetime
#  status            :string           default("pending"), not null
#  via               :string           default("auto"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  hcb_grant_card_id :bigint
#  sent_by_id        :bigint
#  submission_id     :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_grant_payouts_on_hcb_grant_card_id  (hcb_grant_card_id)
#  index_grant_payouts_on_sent_by_id         (sent_by_id)
#  index_grant_payouts_on_status             (status)
#  index_grant_payouts_on_submission_id      (submission_id)
#  index_grant_payouts_on_user_id            (user_id)
#  index_grant_payouts_one_per_submission    (submission_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (hcb_grant_card_id => hcb_grant_cards.id)
#  fk_rails_...  (sent_by_id => users.id)
#  fk_rails_...  (submission_id => submissions.id)
#  fk_rails_...  (user_id => users.id)
#
class GrantPayout < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :gpo
  has_paper_trail

  STATUSES = %w[pending sending sent failed].freeze
  FLAG = :hcb_auto_grants

  belongs_to :submission
  belongs_to :user
  belongs_to :hcb_grant_card, optional: true
  belongs_to :sent_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :via, inclusion: { in: %w[auto manual] }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  scope :unsent, -> { where(status: %w[pending failed sending]) }

  def self.automatic? = Flipper.enabled?(FLAG) && Hcb.configured? && HcbConnection.current&.connected?

  STATUSES.each { |status| define_method(:"#{status}?") { self.status == status } }

  def send!
    return unless GrantPayout.where(id:, status: "pending").update_all(status: "sending", error: nil, updated_at: Time.current) == 1

    reload
    GrantLedger.check!(user)
    card = top_up_card
    if card
      Hcb.topup_card_grant(card.hcb_id, amount_cents:)
      card.update!(amount_cents: card.amount_cents + amount_cents, last_synced_at: Time.current)
    else
      data = Hcb.create_card_grant(amount_cents:, email: user.email, purpose: HcbGrantCard::PURPOSE)
      card = HcbGrantCard.create!(user:, hcb_id: data[:id], email: data[:email] || user.email, amount_cents:, last_synced_at: Time.current)
    end
    update!(status: "sent", via: "auto", hcb_grant_card: card, hcb_reference: card.hcb_id, sent_at: Time.current)
    GrantLedgerSyncJob.perform_later
  rescue GrantLedger::Mismatch => e
    update!(status: "failed", error: e.message)
    Sentry.capture_message("HCB and Fallen disagree on a person's design funding", level: :warning, extra: { payout: public_id, error: e.message })
  rescue Hcb::Error, KeyError => e
    update!(status: "pending", error: e.message)
  rescue StandardError => e
    update!(status: "failed", error: "#{e.class}: #{e.message.truncate(500)}. It may have reached HCB: use Check HCB before sending again.")
    Sentry.capture_exception(e)
  end

  # Settles a failed (or stuck) send from HCB's own numbers: if HCB holds exactly this much more than Fallen has sent
  # the person, it went through; if HCB matches Fallen, it didn't and it goes back to unsent; anything else is left
  # for a person to sort out on HCB.
  def check_hcb!
    return unless failed? || (sending? && updated_at < GrantLedger::SENDING_GRACE.ago)

    GrantLedger.sync!
    extra = GrantLedger.paid_cents(user) - GrantLedger.sent_cents(user)
    if extra == amount_cents
      landed!
    elsif extra.zero?
      update!(status: "pending", error: nil)
    else
      update!(status: "failed", error: "HCB shows #{Money.format(extra)} more than Fallen has sent #{user.email}, which doesn't match " \
        "this #{Money.format(amount_cents)}. Sort it out on HCB, then Mark sent or Check HCB again.")
    end
  rescue Hcb::Error => e
    update!(error: e.message)
  end

  # An admin sent it on HCB by hand. With the grant's id (or link) as the reference, the ledger ties that grant to
  # this person even when HCB has it under another email.
  def mark_sent!(by:, reference:)
    raise ActiveRecord::RecordInvalid, self if sent?

    update!(status: "sent", via: "manual", sent_by: by, hcb_reference: reference.to_s[/cdg_\w+/] || reference.to_s.strip.presence, sent_at: Time.current, error: nil)
  end

  private

  # The person's card to top up, unless HCB has closed it or it is about to expire; then a new one is made.
  def top_up_card
    card = user.hcb_grant_cards.active.first
    copy = card && HcbOrgGrant.find_by(hcb_id: card.hcb_id)
    return card if card.nil? || !Hcb.writes_allowed? || (copy&.status == "active" && !copy.expires_soon?)

    card.update!(status: copy&.status.presence_in(%w[canceled expired]) || "expired")
    nil
  end

  def landed!
    card = user.hcb_grant_cards.active.first
    card ? card.update!(amount_cents: card.amount_cents + amount_cents, last_synced_at: Time.current) : card = adopt_card
    update!(status: "sent", via: "auto", hcb_grant_card: card, hcb_reference: card&.hcb_id, sent_at: Time.current, error: nil)
  end

  # A create that reached HCB but never got back to Fallen: the newest grant to this person that no card points at.
  def adopt_card
    grant = HcbOrgGrant.counted.where(user:).where.not(hcb_id: HcbGrantCard.select(:hcb_id)).order(:id).last
    grant && HcbGrantCard.create!(user:, hcb_id: grant.hcb_id, email: grant.email, amount_cents:, last_synced_at: Time.current)
  end
end
