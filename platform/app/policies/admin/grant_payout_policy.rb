# frozen_string_literal: true

# /admin/grants: admins see every payout, send them, and connect HCB.
class Admin::GrantPayoutPolicy < ApplicationPolicy
  def index? = admin?
  def send_now? = admin? && record.pending? && HcbConnection.current&.connected? && Hcb.configured?
  def check? = admin? && (record.failed? || record.sending?) && HcbConnection.current&.connected? && Hcb.configured?
  def mark_sent? = admin? && !record.sent?
  def connect? = admin?
  def sync? = admin? && HcbConnection.current&.connected? && Hcb.configured?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.all : scope.none
  end
end
