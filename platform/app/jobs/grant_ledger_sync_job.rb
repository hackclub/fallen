# Re-reads every card grant in the HCB org (GrantLedger) and raises the alarm when HCB and Fallen disagree about what
# someone has been given. Runs every few minutes and after each send, so /admin/grants is never far behind HCB.
class GrantLedgerSyncJob < ApplicationJob
  queue_as :background
  limits_concurrency key: "grant_ledger_sync", duration: 5.minutes, on_conflict: :discard

  def perform
    connection = HcbConnection.current
    return unless Hcb.configured? && connection&.connected?

    GrantLedger.sync!
    mismatches = GrantLedger.mismatches(connection.reload.ledger_checked_at)
    unmatched = HcbOrgGrant.unmatched.count
    return if mismatches.empty? && unmatched.zero?

    Sentry.capture_message("HCB and Fallen disagree on design funding", level: :warning, fingerprint: [ "hcb-ledger-mismatch" ],
      extra: { people: mismatches.transform_keys { User.find(it).public_id }, grants_to_unknown_emails: unmatched })
  rescue Hcb::Error => e
    Sentry.capture_message("Couldn't check HCB's card grants: #{e.message}", level: :warning, fingerprint: [ "hcb-ledger-read" ])
  end
end
