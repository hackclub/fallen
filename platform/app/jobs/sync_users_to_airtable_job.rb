# Uploads every user to Airtable (AirtableUsers, config/recurring.yml). Does nothing until AIRTABLE_API_KEY,
# AIRTABLE_BASE_ID and AIRTABLE_USERS_SYNC_ID are set.
class SyncUsersToAirtableJob < ApplicationJob
  queue_as :background
  limits_concurrency to: 1, key: "airtable_users", duration: 10.minutes

  def perform
    return unless Airtable.configured? && ENV["AIRTABLE_USERS_SYNC_ID"].present?

    AirtableUsers.sync
  end
end
