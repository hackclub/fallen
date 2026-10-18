# Sends the next batch of users to Airtable (AirtableUsers, config/recurring.yml). Does nothing until AIRTABLE_API_KEY
# and AIRTABLE_BASE_ID are set.
class SyncUsersToAirtableJob < ApplicationJob
  queue_as :background
  limits_concurrency to: 1, key: "airtable_users", duration: 10.minutes

  def perform
    return unless Airtable.configured?

    AirtableUsers.sync
  end
end
