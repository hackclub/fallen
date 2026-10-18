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
#  hatch_seen_at           :datetime
#  hca_token               :text
#  is_adult                :boolean          default(FALSE), not null
#  is_banned               :boolean          default(FALSE), not null
#  lapse_synced_at         :datetime
#  lapse_token             :text
#  last_seen_at            :datetime
#  pet                     :string
#  roles                   :string           default([]), not null, is an Array
#  signup_source           :jsonb            not null
#  slack_user_token        :text
#  slack_user_token_scopes :string
#  streak_freezes          :integer          default(3), not null
#  timezone                :string           default("UTC"), not null
#  verification_status     :string
#  xp                      :integer          default(0), not null
#  xp_multiplier           :decimal(2, 1)    default(1.0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  hca_id                  :string
#  slack_id                :string
#
# Indexes
#
#  index_users_on_airtable_synced_at  (airtable_synced_at)
#  index_users_on_created_at          (created_at)
#  index_users_on_discarded_at        (discarded_at)
#  index_users_on_email               (email)
#  index_users_on_hca_id              (hca_id) UNIQUE
#  index_users_on_last_seen_at        (last_seen_at)
#  index_users_on_roles               (roles) USING gin
#  index_users_on_slack_id            (slack_id)
#
class UserSerializer < ApplicationSerializer
  typelize_from User
  typelize id: :string, avatar: :string, is_admin: :boolean, is_staff: :boolean, pet_form: :number, next_stage_xp: [ :number, nullable: true ], stage_progress: :number
  attributes :display_name, :email, :roles, :is_banned, :pet, :xp
  attribute(:id) { |user| user.public_id }
  attribute(:avatar) { |user| user.avatar_url }
  attribute(:is_admin, &:admin?)
  attribute(:is_staff, &:staff?)
  attribute(:pet_form, &:pet_form)
  attribute(:next_stage_xp, &:next_stage_xp)
  attribute(:stage_progress, &:stage_progress)
end
