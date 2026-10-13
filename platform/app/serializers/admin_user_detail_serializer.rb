# frozen_string_literal: true

# Admin-only. Everything on /admin/users/:id.
class AdminUserDetailSerializer < AdminUserSerializer
  attributes :hca_id, :timezone, :verification_status, :is_adult
end
