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
#  pet                     :string
#  roles                   :string           default([]), not null, is an Array
#  slack_user_token        :text
#  slack_user_token_scopes :string
#  streak_freezes          :integer          default(3), not null
#  timezone                :string           default("UTC"), not null
#  verification_status     :string
#  xp                      :integer          default(0), not null
#  xp_multiplier           :decimal(2, 1)    default(1.0), not null
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
class User < ApplicationRecord
  ROLES = %w[user reviewer admin].freeze
  FALLBACK_AVATAR = "/static-assets/pfp_fallback.webp"
  # Cachet redirects to the current Slack profile picture, so stored Slack image URLs never go stale.
  CACHET_URL = "https://cachet.hackclub.com"
  # The desktop pet picked during onboarding, an egg until the first journal (Evolution). It is also the team (Team).
  PETS = %w[lulu sami].freeze

  include PublicIdentifiable
  include Discardable
  include PgSearch::Model

  set_public_id_prefix :usr
  has_paper_trail

  pg_search_scope :search, against: %i[display_name email slack_id], using: { tsearch: { prefix: true } }

  encrypts :hca_token, :slack_user_token

  has_many :projects, dependent: :destroy
  has_many :journals, dependent: :destroy
  has_many :xp_entries, dependent: :destroy

  validates :hca_id, :email, :display_name, :timezone, presence: true
  validates :hca_id, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :roles, presence: true
  validates :pet, inclusion: { in: PETS }, allow_nil: true
  validate :roles_are_known

  scope :admins, -> { where("roles @> ARRAY[?]::varchar[]", "admin") }
  scope :with_role, ->(role) { where("roles @> ARRAY[?]::varchar[]", role.to_s) }
  scope :banned, -> { where(is_banned: true) }
  scope :on_a_team, -> { kept.where(is_banned: false).where.not(pet: nil) }

  def has_role?(role) = roles.include?(role.to_s)
  def admin? = has_role?(:admin)
  def reviewer? = has_role?(:reviewer)
  def staff? = admin? || reviewer?

  def add_role(role)
    return true if has_role?(role)

    update(roles: roles + [ role.to_s ])
  end

  def remove_role(role)
    update(roles: roles - [ role.to_s ])
  end

  def avatar_url
    return "#{CACHET_URL}/users/#{slack_id}/r" if slack_id.present?

    avatar.presence || FALLBACK_AVATAR
  end

  def slack_mention = slack_id.present? ? "<@#{slack_id}>" : display_name

  def local_date(time = Time.current) = time.in_time_zone(timezone).to_date

  def team = Team.for(self)
  def hatched? = xp.positive?
  def stage = Evolution.stage(xp) { projects.kept.approved.exists? }
  def next_stage_xp = Evolution.next_stage_xp(xp)
  def stage_progress = Evolution.progress(xp)

  # What the pet looks like: 0 is the egg, then the stage.
  def pet_form = hatched? ? stage : 0

  # users.xp is the sum of the ledger's kept entries, recounted by XpEntry after every change. Never incremented, so it cannot drift.
  def self.recount_xp(ids)
    where(id: ids).update_all("xp = (SELECT COALESCE(SUM(amount), 0) FROM xp_entries WHERE xp_entries.user_id = users.id AND xp_entries.discarded_at IS NULL)")
  end

  # Journals posted from the web go to Slack as this person when they have connected Slack (SlackAuthController).
  def slack_connected? = slack_user_token.present?

  def disconnect_slack! = update!(slack_user_token: nil, slack_user_token_scopes: nil)

  def touch_last_seen
    update_column(:last_seen_at, Time.current) if last_seen_at.nil? || last_seen_at < 5.minutes.ago
  end

  # Signs a user in from an HCA authorization code: exchanges the code, loads the identity,
  # then creates or updates the local user. Slack profile details are refreshed in a background job.
  def self.from_hca_code!(code, redirect_uri)
    token_data = HCA.exchange_code_for_token(code, redirect_uri)
    access_token = token_data&.dig("access_token")
    raise HCA::Error, "HCA did not return an access token" if access_token.blank?

    identity = HCA.identity(access_token)
    raise HCA::Error, "HCA did not return an identity" if identity.blank? || identity["id"].blank?

    user = find_or_initialize_by(hca_id: identity["id"])
    user.assign_from_hca(identity, access_token)
    user.save!
    SyncSlackProfileJob.perform_later(user) if user.slack_id.present?
    user
  end

  def assign_from_hca(identity, access_token)
    self.hca_token = access_token
    self.email = identity["primary_email"].presence || email
    self.display_name = [ identity["first_name"], identity["last_name"] ].compact_blank.join(" ").presence || display_name.presence || "Hack Clubber"
    self.avatar = identity["profile_picture"].presence || avatar
    self.slack_id = identity["slack_id"].presence || slack_id
    self.verification_status = identity["verification_status"].presence || verification_status
    self.is_adult = HCA.adult?(identity) if identity.key?("birthday")
    self.roles = [ "user" ] if roles.blank?
  end

  # Pulls display name and timezone from the Slack workspace. Needs SLACK_BOT_TOKEN with users:read.
  def sync_slack_profile!
    return if slack_id.blank?

    info = SlackBot.client.users_info(user: slack_id)
    profile = info.user.profile
    updates = {}
    updates[:display_name] = profile.display_name.presence || profile.real_name.presence || display_name
    updates[:timezone] = info.user.tz.presence || timezone
    update!(updates)
  end

  private

  def roles_are_known
    unknown = roles - ROLES
    errors.add(:roles, "contains unknown roles: #{unknown.join(', ')}") if unknown.any?
  end
end
