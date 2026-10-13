# frozen_string_literal: true

# The signed-in user as shared with every page (ApplicationController#inertia_share).
# == Schema Information
#
# Table name: users
#
#  id                      :bigint           not null, primary key
#  avatar                  :string
#  discarded_at            :datetime
#  display_name            :string           not null
#  email                   :string           not null
#  hca_token               :text
#  is_adult                :boolean          default(FALSE), not null
#  is_banned               :boolean          default(FALSE), not null
#  last_seen_at            :datetime
#  roles                   :string           default([]), not null, is an Array
#  slack_user_token        :text
#  slack_user_token_scopes :string
#  timezone                :string           default("UTC"), not null
#  verification_status     :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  hca_id                  :string           not null
#  slack_id                :string
#
# Indexes
#
#  index_users_on_created_at    (created_at)
#  index_users_on_discarded_at  (discarded_at)
#  index_users_on_email         (email)
#  index_users_on_hca_id        (hca_id) UNIQUE
#  index_users_on_last_seen_at  (last_seen_at)
#  index_users_on_roles         (roles) USING gin
#  index_users_on_slack_id      (slack_id)
#
class UserSerializer < ApplicationSerializer
  typelize_from User
  typelize id: :string, avatar: :string, is_admin: :boolean, is_staff: :boolean
  attributes :display_name, :email, :roles, :is_banned
  attribute(:id) { |user| user.public_id }
  attribute(:avatar) { |user| user.avatar_url }
  attribute(:is_admin, &:admin?)
  attribute(:is_staff, &:staff?)
end
