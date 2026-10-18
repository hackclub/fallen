# frozen_string_literal: true

# Copies users to the Users table in Airtable (AIRTABLE_USERS_TABLE), matched on ID, their public id. Each run sends
# the rows synced longest ago, never-synced first. A change to the user row (User) or their XP (User.recount_xp)
# clears users.airtable_synced_at so it goes at the front of the next run; anything else is caught on the next lap.
# Tokens never leave the app.
module AirtableUsers
  PER_RUN = 100
  MERGE_ON = "ID"

  module_function

  def table = ENV.fetch("AIRTABLE_USERS_TABLE", "Users")

  def sync(limit: PER_RUN)
    started = Time.current
    users = User.order(Arel.sql("airtable_synced_at ASC NULLS FIRST"), :id).limit(limit).to_a
    return 0 if users.empty?

    Airtable.upsert(table, rows(users), merge_on: MERGE_ON)
    # A user changed while this ran keeps the cleared timestamp and goes again next run.
    User.where(id: users.map(&:id)).where(updated_at: ..started).update_all(airtable_synced_at: started)
    users.size
  end

  def rows(users)
    ids = users.map(&:id)
    journals = Journal.kept.where(user_id: ids).group(:user_id)
    stats = {
      journals: journals.count,
      minutes: journals.sum(:duration_minutes),
      first_journal: journals.minimum(:created_at),
      last_journal: journals.maximum(:created_at),
      projects: Project.kept.where(user_id: ids).group(:user_id).count,
      approved: Project.kept.approved.where(user_id: ids).group(:user_id).count
    }
    users.map { |user| row(user, stats) }
  end

  def row(user, stats)
    approved = stats[:approved][user.id].to_i
    {
      "ID" => user.public_id,
      "Name" => user.display_name,
      "Email" => user.email,
      "HCA ID" => user.hca_id,
      "Slack ID" => user.slack_id,
      "Avatar" => user.avatar_url.start_with?("http") ? user.avatar_url : nil,
      "Verification Status" => user.verification_status,
      "Adult" => user.is_adult,
      "Banned" => user.is_banned,
      "Roles" => user.roles,
      "Timezone" => user.timezone,
      "Pet" => user.pet,
      "Slack Connected" => user.slack_connected?,
      "XP" => user.xp,
      "XP Multiplier" => user.xp_multiplier.to_f,
      "Streak Freezes" => user.streak_freezes,
      "Stage" => user.hatched? ? Evolution.stage(user.xp) { approved.positive? } : 0,
      "Projects" => stats[:projects][user.id].to_i,
      "Approved Projects" => approved,
      "Journals" => stats[:journals][user.id].to_i,
      "Hours" => (stats[:minutes][user.id].to_i / 60.0).round(2),
      "First Journal At" => stats[:first_journal][user.id]&.iso8601,
      "Last Journal At" => stats[:last_journal][user.id]&.iso8601,
      "Last Seen At" => user.last_seen_at&.iso8601,
      "Signed Up At" => user.created_at.iso8601,
      "Deleted At" => user.discarded_at&.iso8601
    }
  end
end
