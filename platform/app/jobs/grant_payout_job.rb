class GrantPayoutJob < ApplicationJob
  queue_as :background
  # One at a time per person, so two payouts can't both make them a card, and a check never races a send.
  limits_concurrency key: ->(payout, **) { "grant_payout_#{payout.user_id}" }, duration: 5.minutes
  discard_on ActiveJob::DeserializationError

  # `by_hand`: an admin pressed Send on /admin/grants, so it goes even with automatic sending off.
  # `check`: an admin pressed Check HCB on a failed one.
  def perform(payout, by_hand: false, check: false)
    return payout.check_hcb! if check

    payout.send! if payout.pending? && (by_hand || GrantPayout.automatic?)
  end
end
