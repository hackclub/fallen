# frozen_string_literal: true

# Admin-only. Rows in /admin/transfers (ProjectTransfer). `user` is null when no account has the form's email.
class AdminProjectTransferSerializer < ApplicationSerializer
  typelize_from ProjectTransfer
  typelize id: :string, snapshot_minutes: [ :number, nullable: true ], owner_check: [ :string, nullable: true ],
           submitted_at: :string, decided_at: [ :string, nullable: true ]
  attributes :status, :email, :name, :project_name, :source, :source_url, :claimed_minutes, :approved_minutes, :xp,
             :error, :submitted_at, :decided_at
  attribute(:id) { |transfer| transfer.public_id }
  attribute(:snapshot_minutes, &:snapshot_minutes)
  attribute(:owner_check, &:owner_check)
  one :user, resource: AdminUserSerializer
end
