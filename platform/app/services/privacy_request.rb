# frozen_string_literal: true

# Deletes everything Fallen holds about one person, found only from a privacy hub token's subject.
# Dry runs and exports run the same deletion and roll it back, so the counts a reviewer approves are the
# counts the real run produces. What goes and what stays is written up in docs/privacy.md.
class PrivacyRequest
  BANNED_PLACEHOLDER = {
    email: "deleted@users.invalid",
    display_name: "Deleted user",
    avatar: nil,
    slack_id: nil,
    hca_token: nil,
    timezone: "UTC",
    verification_status: nil,
    is_adult: false,
    last_seen_at: nil
  }.freeze

  def initialize(subject)
    @subject = subject
  end

  # Returns { found:, deleted:, retained: }. Changes are committed only when commit is true.
  def run(commit:)
    result = nil
    ActiveRecord::Base.transaction do
      result = delete_everything
      raise ActiveRecord::Rollback unless commit
    end
    result
  end

  private

  def delete_everything
    users = matching_users.lock.to_a
    return { found: false, deleted: {}, retained: [] } if users.empty?

    ids = users.map(&:id)
    banned, removable = users.partition(&:is_banned?)
    deleted = {}
    retained = []

    deleted["versions"] = PaperTrail::Version.where(item_type: "User", item_id: ids).delete_all
    deleted["users"] = User.where(id: removable.map(&:id)).delete_all

    attributed = PaperTrail::Version.where(whodunnit: ids.map(&:to_s)).update_all(whodunnit: nil)
    if attributed.positive?
      retained << { type: "versions", count: attributed,
                    reason: "history of changes this person made to other accounts as staff; kept for those accounts with the author removed" }
    end

    if banned.any?
      User.where(id: banned.map(&:id)).update_all(BANNED_PLACEHOLDER.merge(updated_at: Time.current))
      retained << { type: "banned users", count: banned.size,
                    reason: "kept as an anonymous placeholder holding only the Hack Club Auth id and ban flag, so the ban still applies if they sign in again; name, email, avatar, Slack id and tokens are wiped" }
    end

    { found: true, deleted: deleted.select { |_, count| count.positive? }, retained: retained }
  end

  def matching_users
    emails = Array(@subject["emails"]).grep(String).map(&:downcase)
    scope = User.where("lower(email) IN (?)", emails)
    scope = scope.or(User.where(slack_id: @subject["slack_id"])) if @subject["slack_id"].is_a?(String) && @subject["slack_id"].present?
    scope = scope.or(User.where(hca_id: @subject["identity_id"])) if @subject["identity_id"].is_a?(String) && @subject["identity_id"].present?
    scope
  end
end
