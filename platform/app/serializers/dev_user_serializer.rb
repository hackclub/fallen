# frozen_string_literal: true

# Users offered by the development-only sign-in dropdown on the landing page (LandingController).
class DevUserSerializer < ApplicationSerializer
  typelize_from User
  typelize id: :string, sign_in_url: :string
  attributes :display_name, :email, :roles
  attribute(:id) { |user| user.public_id }
  attribute(:sign_in_url) { |user| Rails.application.routes.url_helpers.dev_sign_in_as_path(user.public_id) }
end
