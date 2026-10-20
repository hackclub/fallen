# Copies Fallout's email link codes from its Airtable (FalloutInvite) with Fallen's Airtable key. Not scheduled: the
# codes were copied once, so run it by hand if Fallout sends emails to new people. Does nothing until Airtable is configured.
class SyncFalloutInvitesJob < ApplicationJob
  queue_as :background
  limits_concurrency to: 1, key: "fallout_invites", duration: 10.minutes

  def perform
    return unless FalloutInvite.configured?

    FalloutInvite.sync
  end
end
