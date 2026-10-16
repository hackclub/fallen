# frozen_string_literal: true

# Accounts offered by the development-only sign in page (DevController).
class DevUserSerializer < ApplicationSerializer
  typelize_from User
  typelize id: :string
  attributes :display_name, :email, :roles, :is_banned, :is_adult, :pet, :last_seen_at, :created_at
  attribute(:id) { |user| user.public_id }
end
