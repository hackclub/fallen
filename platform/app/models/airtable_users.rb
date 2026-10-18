# frozen_string_literal: true

# Copies every user to the Users table in Airtable through the Sync API (Airtable.sync), keyed on ID, their public id.
# The table is set up once in Airtable as a Sync API table (AIRTABLE_USERS_TABLE, AIRTABLE_USERS_SYNC_ID) with ID as
# its unique field. A user deleted here, including by a privacy request, drops out of Airtable on the next upload.
# Tokens never leave the app.
module AirtableUsers
  module_function

  def sync
    rows = rows(User.order(:id).to_a)
    Airtable.sync(ENV.fetch("AIRTABLE_USERS_TABLE", "Users"), ENV.fetch("AIRTABLE_USERS_SYNC_ID"), rows) if rows.any?
    rows.size
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
