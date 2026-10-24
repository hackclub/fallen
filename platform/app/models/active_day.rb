# A day in the stats' timezone (ProgramStats::ZONE) someone opened the site (User#touch_last_seen), for daily active counts on /admin/stats. One row per
# person per day and no integer id, so no change history: there is nothing to change.
# == Schema Information
#
# Table name: active_days
#
#  day     :date             not null, primary key
#  user_id :bigint           not null, primary key
#
# Indexes
#
#  index_active_days_on_day  (day)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ActiveDay < ApplicationRecord
  self.primary_key = %i[user_id day]

  belongs_to :user

  def self.day(at) = at.in_time_zone(ProgramStats::ZONE).to_date

  # Sets their last_seen_at too, in the same statement, so the day's first request costs no extra query.
  def self.record(user, at = Time.current)
    connection.update(sanitize_sql_array([ <<~SQL.squish, at, user.id, user.id, day(at) ]))
      WITH seen AS (UPDATE users SET last_seen_at = ? WHERE id = ?)
      INSERT INTO active_days (user_id, day) VALUES (?, ?) ON CONFLICT DO NOTHING
    SQL
    user.last_seen_at = at
    user.clear_attribute_changes(%i[last_seen_at])
  end
end
