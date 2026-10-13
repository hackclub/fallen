# frozen_string_literal: true

# Admin-only. Rows in /admin/projects and on /admin/users/:id.
class AdminProjectSerializer < ProjectSerializer
  typelize discarded_at: [ :string, nullable: true ]
  attributes :discarded_at
  one :user, resource: AdminUserSerializer
end
