# frozen_string_literal: true

# Admin-only. Rows in /admin/users.
class AdminUserSerializer < UserSerializer
  typelize discarded_at: [ :string, nullable: true ]
  attributes :slack_id, :last_seen_at, :created_at, :discarded_at
end
