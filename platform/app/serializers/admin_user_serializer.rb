# frozen_string_literal: true

# Admin-only. Rows in /admin/users.
class AdminUserSerializer < UserSerializer
  attributes :last_seen_at, :created_at
end
