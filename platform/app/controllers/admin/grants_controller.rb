# Design funding (GrantPayout): what approved submissions are owed, sending it through HCB, and connecting HCB.
class Admin::GrantsController < Admin::ApplicationController
  include OauthState

  TABS = %w[unsent sent all hcb].freeze

  def index
    tab = TABS.include?(params[:tab]) ? params[:tab] : "unsent"
    scope = policy_scope([ :admin, GrantPayout ])
    connection = HcbConnection.current

    render inertia: "Admin/Grants/Index", props: {
      tab:,
      hcb: {
        configured: Hcb.configured?, connected: connection&.connected? || false, expires_at: connection&.token_expires_at,
        connected_by: connection && PersonSerializer.render(connection.connected_by), writes: Hcb.writes_allowed?,
        automatic: Flipper.enabled?(GrantPayout::FLAG), flag: GrantPayout::FLAG.to_s,
        checked_at: connection&.ledger_checked_at, check_error: connection&.ledger_error
      },
      totals: InertiaRails.defer(group: "table") { { unsent: scope.unsent.sum(:amount_cents), sent: scope.where(status: "sent").sum(:amount_cents), unsent_count: scope.unsent.count } },
      ledger: InertiaRails.defer(group: "table") { ledger(connection&.ledger_checked_at) },
      **(tab == "hcb" ? hcb_table : payout_table(scope, tab))
    }
  end

  def send_now
    payout = find_and_authorize(:send_now?)
    GrantPayoutJob.perform_later(payout, by_hand: true)
    redirect_back fallback_location: admin_grants_path, notice: "Sending #{Money.format(payout.amount_cents)} to #{payout.user.email}. Reload in a moment."
  end

  def check
    payout = find_and_authorize(:check?)
    GrantPayoutJob.perform_later(payout, check: true)
    redirect_back fallback_location: admin_grants_path, notice: "Checking HCB for #{Money.format(payout.amount_cents)} to #{payout.user.email}. Reload in a moment."
  end

  def mark_sent
    payout = find_and_authorize(:mark_sent?)
    payout.mark_sent!(by: true_user, reference: params[:reference])
    redirect_back fallback_location: admin_grants_path, notice: "Marked as sent."
  end

  def sync
    authorize [ :admin, GrantPayout ], :sync?
    GrantLedgerSyncJob.perform_later
    redirect_back fallback_location: admin_grants_path(tab: "hcb"), notice: "Checking every card grant on HCB. Reload in a moment."
  end

  # "Connect HCB": the program's organization token, which every payout uses.
  def connect
    authorize [ :admin, GrantPayout ], :connect?
    return redirect_to(admin_grants_path, alert: "Set HCB_CLIENT_ID, HCB_CLIENT_SECRET and HCB_ORGANIZATION_ID first.") unless Hcb.configured?

    redirect_to Hcb.authorize_url(hcb_callback_admin_grants_url, issue_oauth_state), allow_other_host: true
  end

  def callback
    authorize [ :admin, GrantPayout ], :connect?
    return redirect_to(admin_grants_path, alert: "Connecting HCB failed (state mismatch). Try again.") unless consume_oauth_state(params[:state])
    return redirect_to(admin_grants_path, alert: "Connecting HCB was cancelled.") if params[:error].present?

    HcbConnection.connect!(Hcb.exchange_code(params[:code], hcb_callback_admin_grants_url), by: true_user)
    redirect_to admin_grants_path, notice: "HCB connected."
  rescue Faraday::Error => e
    Sentry.capture_exception(e)
    redirect_to admin_grants_path, alert: "Connecting HCB failed: #{e.message}"
  end

  private

  def payout_table(scope, tab)
    rows = (tab == "unsent" ? scope.unsent : tab == "sent" ? scope.where(status: "sent") : scope).order(created_at: tab == "unsent" ? :asc : :desc)
    deferred_table(rows.includes(:sent_by, :user, submission: :project), AdminGrantPayoutSerializer, :payouts)
  end

  # Every grant in the HCB org, people whose totals disagree first, then grants to emails no Fallen account has.
  def hcb_table
    grants = policy_scope([ :admin, HcbOrgGrant ])
    deferred_table(grants.includes(:user, :ignored_by).order(Arel.sql("user_id IS NOT NULL, ignored_at IS NOT NULL, email, hcb_id")),
      AdminHcbOrgGrantSerializer, :grants) do
      { mismatches: GrantLedger.mismatches(HcbConnection.current&.ledger_checked_at) }
    end
  end

  # What /admin/grants leads with: anyone HCB and Fallen disagree about.
  def ledger(checked_at)
    mismatches = GrantLedger.mismatches(checked_at)
    people = User.where(id: mismatches.keys.first(20)).index_by(&:id)
    unmatched, total, balance, expiring = HcbOrgGrant.counted.pick(Arel.sql(HcbOrgGrant.sanitize_sql_array([ <<~SQL.squish, 7.days.from_now.to_date ])))
      COUNT(*) FILTER (WHERE user_id IS NULL), COALESCE(SUM(amount_cents), 0),
      COALESCE(SUM(balance_cents) FILTER (WHERE status = 'active'), 0),
      COUNT(*) FILTER (WHERE status = 'active' AND balance_cents > 0 AND expires_on <= ?)
    SQL
    {
      mismatch_count: mismatches.size,
      mismatches: people.map { |id, user| { person: PersonSerializer.new(user).serializable_hash, email: user.email, hcb_cents: mismatches[id][0], fallen_cents: mismatches[id][1] } },
      unmatched_count: unmatched, hcb_total_cents: total, hcb_balance_cents: balance, expiring_count: expiring
    }
  end

  def find_and_authorize(action)
    payout = GrantPayout.find_by_public_id!(params[:id])
    authorize [ :admin, payout ], action
    payout
  end
end
