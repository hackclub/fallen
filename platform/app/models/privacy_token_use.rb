# == Schema Information
#
# Table name: privacy_token_uses
#
#  jti     :text             not null, primary key
#  used_at :datetime         not null
#
# Every privacy hub token we have accepted, so a replayed token is refused. Kept in the database on purpose:
# the hub docs warn that cache clients can make every write look like a duplicate.
class PrivacyTokenUse < ApplicationRecord
  self.primary_key = :jti

  # True the first time a jti is seen, false on a replay.
  def self.record(jti)
    where(used_at: ...1.day.ago).delete_all
    insert({ jti: jti }, returning: :jti).any?
  end
end
