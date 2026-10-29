# frozen_string_literal: true

# Admin-only. A change to someone's streak, or an incident (StreakAdjustment), in the logs on /admin/users/:id and
# /admin/streaks. `can_undo` is the admin's permission; `undo_error` what stands in the way anyway.
class AdminStreakAdjustmentSerializer < ApplicationSerializer
  typelize id: :string, kind: "'excuse' | 'freezes' | 'set' | 'xp'", starts_on: [ :string, nullable: true ], ends_on: [ :string, nullable: true ],
    days_text: [ :string, nullable: true ], freezes: [ :number, nullable: true ], multiplier: [ :number, nullable: true ], xp: [ :number, nullable: true ],
    reason: :string,
    message: [ :string, nullable: true ], notify: :boolean, reprice: :boolean, effect: "Record<string, number | number[]>", incident: :boolean,
    admin: "{ id: string; name: string; avatar: string } | null", undone_by: [ :string, nullable: true ], created_at: :string,
    discarded_at: [ :string, nullable: true ], undo_error: [ :string, nullable: true ], user: [ "AdminUser", nullable: true ]

  attributes :kind, :starts_on, :ends_on, :freezes, :xp, :reason, :message, :notify, :reprice, :effect, :created_at, :discarded_at
  attribute(:id, &:public_id)
  attribute(:days_text) { |adjustment| adjustment.days_text if adjustment.excuse? }
  attribute(:multiplier) { |adjustment| adjustment.multiplier&.to_f }
  attribute(:incident, &:incident?)
  attribute(:admin) { |adjustment| adjustment.admin && { id: adjustment.admin.public_id, name: adjustment.admin.display_name, avatar: adjustment.admin.avatar_url } }
  attribute(:undone_by) { |adjustment| adjustment.undone_by&.display_name }
  attribute(:undo_error) { |adjustment| adjustment.undo_error unless adjustment.discarded? || adjustment.incident? }
  one :user, resource: AdminUserSerializer
end
