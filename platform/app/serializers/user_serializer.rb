# frozen_string_literal: true

# The signed-in user as shared with every page (ApplicationController#inertia_share).
class UserSerializer < ApplicationSerializer
  typelize_from User
  typelize id: :string, avatar: :string, is_admin: :boolean, is_staff: :boolean
  attributes :display_name, :email, :roles, :is_banned
  attribute(:id) { |user| user.public_id }
  attribute(:avatar) { |user| user.avatar_url }
  attribute(:is_admin, &:admin?)
  attribute(:is_staff, &:staff?)
end
