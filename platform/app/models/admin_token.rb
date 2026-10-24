# frozen_string_literal: true

# An admin's credential for the MCP server at POST /mcp (McpController, docs/mcp.md). Only the SHA-256 digest is
# stored; the raw token exists in the one response that minted it. Every token expires. Revoking keeps the row,
# because the McpActions it made point at it. Losing the admin role, a ban or deleting the account revokes every
# live token (User#revoke_admin_tokens), and McpController checks the role again on every call anyway.
# == Schema Information
#
# Table name: admin_tokens
#
#  id           :bigint           not null, primary key
#  expires_at   :datetime         not null
#  last_used_at :datetime
#  name         :string           not null
#  revoked_at   :datetime
#  token_digest :string           not null
#  token_hint   :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_admin_tokens_on_token_digest  (token_digest) UNIQUE
#  index_admin_tokens_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class AdminToken < ApplicationRecord
  PREFIX = "fallen_admin_"
  PER_USER = 5
  DEFAULT_LIFETIME = 30.days
  MAX_LIFETIME = 90.days
  TOUCH_INTERVAL = 5.minutes
  # name@device, like an SSH key's comment, so the list says whose token it is and where it lives at a glance.
  NAME_PART = "[a-z0-9][a-z0-9._-]{0,29}"
  NAME_FORMAT = /\A#{NAME_PART}@#{NAME_PART}\z/

  has_paper_trail

  belongs_to :user
  has_many :mcp_actions, dependent: :restrict_with_exception

  validates :name, format: { with: NAME_FORMAT, message: "must look like name@device: lowercase letters, numbers, dots, dashes and underscores" },
    on: :create
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validate :owner_is_an_admin, on: :create
  validate :within_limit, on: :create

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :live, -> { where(revoked_at: nil).where(expires_at: Time.current..) }

  attr_reader :token

  # The name half a new token starts with: the first word of the admin's name, as the form would type it.
  def self.default_handle(user) = user.display_name.to_s.split.first.to_s.parameterize(separator: "-").presence&.first(30) || "admin"

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token.to_s)

  def self.mint(user:, name:, lifetime: DEFAULT_LIFETIME)
    token = "#{PREFIX}#{SecureRandom.base58(40)}"
    record = user.admin_tokens.create!(name: name.to_s.strip, token_digest: digest(token), token_hint: token.last(4),
                                       expires_at: Time.current + lifetime.clamp(1.day, MAX_LIFETIME))
    record.instance_variable_set(:@token, token)
    record
  end

  # A string that isn't shaped like ours never reaches the database, and a revoked or expired token never comes back.
  def self.authenticate(token)
    return nil unless token.is_a?(String) && token.start_with?(PREFIX) && token.length < 100

    live.find_by(token_digest: digest(token))
  end

  def live? = revoked_at.nil? && expires_at.future?

  def revoke!
    update!(revoked_at: Time.current) if revoked_at.nil?
  end

  def touch_used!
    return if last_used_at.present? && last_used_at > TOUCH_INTERVAL.ago

    update_column(:last_used_at, Time.current)
  end

  private

  def owner_is_an_admin
    errors.add(:base, "Only an admin can hold an MCP token.") unless user&.admin? && !user.is_banned? && !user.discarded?
  end

  def within_limit
    errors.add(:base, "You can have #{PER_USER} MCP tokens at most. Revoke one first.") if user && user.admin_tokens.live.count >= PER_USER
  end
end
