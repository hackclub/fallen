# frozen_string_literal: true

# Admin-only. Everything on /admin/users/:id.
class AdminUserDetailSerializer < AdminUserSerializer
  typelize xp_multiplier: :number
  attributes :hca_id, :timezone, :verification_status, :is_adult, :streak_freezes
  attribute(:xp_multiplier) { |user| user.xp_multiplier.to_f }
end
