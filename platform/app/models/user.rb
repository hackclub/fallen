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
#  pet_switched_at         :datetime
#  roles                   :string           default([]), not null, is an Array
#  signup_source           :jsonb            not null
#  slack_skipped_at        :datetime
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
class User < ApplicationRecord
  ROLES = %w[user reviewer admin].freeze
  FALLBACK_AVATAR = "/static-assets/pfp_fallback.webp"
  # Cachet redirects to the current Slack profile picture, so stored Slack image URLs never go stale.
  CACHET_URL = "https://cachet.hackclub.com"
  # The desktop pet picked during onboarding, an egg until the first journal (Evolution). It is also the team (Team),
  # so switching it is limited (PetSwitch).
  PETS = %w[lulu sami].freeze
  SLACK_ID = /\A[UW][A-Z0-9]{6,20}\z/

  include PublicIdentifiable
  include Discardable
  include PgSearch::Model

  set_public_id_prefix :usr
  # Left from the per-record Airtable sync, which AirtableUsers replaced. Drop the column once this is deployed.
  self.ignored_columns += %w[airtable_synced_at]
  has_paper_trail

  pg_search_scope :search, against: %i[display_name email slack_id], using: { tsearch: { prefix: true } }

  encrypts :hca_token, :slack_user_token, :lapse_token

  has_many :projects, dependent: :destroy
  has_many :journals, dependent: :destroy
  has_many :xp_entries, dependent: :destroy
  has_many :huddle_sessions, dependent: :destroy
  has_many :timer_sessions, dependent: :destroy
  has_many :huddle_pauses, dependent: :destroy
  has_many :time_milestones, dependent: :delete_all
  has_many :lapse_timelapses, dependent: :destroy

  validates :email, :display_name, :timezone, presence: true
  validates :hca_id, uniqueness: true, allow_nil: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :roles, presence: true
  validates :pet, inclusion: { in: PETS, message: "That pet doesn't exist." }, allow_nil: true
  validate :pet_switch_allowed, if: :switching_pet?
  validate :roles_are_known

  # Huddle visits are recorded by Slack id before anyone signs up (HuddleSyncJob); they become theirs once linked.
  # Sami's multiplier stays with Sami, so a switch starts the new team at 1x.
  before_save -> { assign_attributes(pet_switched_at: Time.current, xp_multiplier: 1.0) }, if: :switching_pet?
  after_save -> { HuddleSession.where(slack_id: slack_id, user_id: nil).update_all(user_id: id) }, if: -> { saved_change_to_slack_id? && slack_id.present? }
  # Finishing onboarding (picking a pet) or linking Slack while sitting in the huddle gets a welcome (HuddleWelcomeJob).
  after_commit -> { HuddleWelcomeJob.perform_later(self) }, on: %i[create update], if: :just_joined_fallen?
  after_commit -> { JoinMembersChannelJob.perform_later(self) }, on: %i[create update], if: :just_joined_fallen?

  scope :admins, -> { where("roles @> ARRAY[?]::varchar[]", "admin") }
  scope :with_role, ->(role) { where("roles @> ARRAY[?]::varchar[]", role.to_s) }
  scope :banned, -> { where(is_banned: true) }
  scope :verified, -> { where.not(hca_id: nil) }
  scope :trial, -> { where(hca_id: nil) }
  scope :on_a_team, -> { kept.verified.where(is_banned: false).where.not(pet: nil) }

  def has_role?(role) = roles.include?(role.to_s)
  def admin? = has_role?(:admin)
  def reviewer? = has_role?(:reviewer)
  def staff? = admin? || reviewer?

  # Started with just an email (TrialSessionsController) or from the Slack join button (join_from_slack!): can do the
  # onboarding and make a project, nothing more, until they sign in with Hack Club Auth.
  def trial? = hca_id.nil?

  def self.start_trial!(email:, signup_source: {})
    create!(email: email, display_name: email.split("@").first, roles: [ "user" ], signup_source: signup_source)
  end

  # The Slack join button (Api::SlackJoinsController) makes a trial account from their Slack profile, so they are in
  # Airtable before they visit. Signing in with Hack Club Auth claims it by Slack ID (from_hca_code!). Nothing is made
  # when an account already has the Slack ID or the email, or Slack has no email for them. `signup_source` is the UTM
  # tags and `ref` the button sent; `ref` is "slack-join" when it sent none.
  def self.join_from_slack!(slack_id, signup_source: {})
    return if kept.exists?(slack_id: slack_id)

    info = SlackAvatars.client.users_info(user: slack_id).user
    email = info.profile.email.to_s.strip.downcase
    return if email.blank? || kept.exists?(email: email)

    create!(
      email: email, slack_id: slack_id, roles: [ "user" ], signup_source: { "ref" => "slack-join", **signup_source, "landing_path" => "/api/slack/join" },
      display_name: info.profile.display_name.presence || info.profile.real_name.presence || email.split("@").first,
      timezone: ActiveSupport::TimeZone[info.tz.to_s] ? info.tz : "UTC"
    )
  end

  def self.joined_from_slack(slack_id) = slack_id.present? ? kept.trial.find_by(slack_id: slack_id) : nil

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
  def pet_switch = PetSwitch.new(self)
  def hatched? = xp.positive?

  # The first time they watch their egg hatch on the site, their pet thanks them in their project's thread.
  def hatch_seen!
    return if hatch_seen_at? || !hatched?

    update!(hatch_seen_at: Time.current)
    HatchCelebrationJob.perform_later(self)
  end

  # The thread the first journal went to, where the pet's welcome is posted.
  def first_journal_project = journals.kept.order(:created_at).first&.project
  def stage = Evolution.stage(xp) { projects.kept.approved.exists? }
  def next_stage_xp = Evolution.next_stage_xp(xp)
  def stage_progress = Evolution.progress(xp)

  # What the pet looks like: 0 is the egg, then the stage.
  def pet_form = hatched? ? stage : 0

  # users.xp is the sum of the ledger's kept entries, recounted by XpEntry after every change. Never incremented, so it cannot drift.
  def self.recount_xp(ids)
    where(id: ids).update_all("xp = (SELECT COALESCE(SUM(amount), 0) FROM xp_entries WHERE xp_entries.user_id = users.id AND xp_entries.discarded_at IS NULL)")
  end

  # Journals posted from the web go to Slack as this person when they have connected Slack (SlackAuthController),
  # or by the bot under their name once they chose to skip that (SlackMessaging.post). Either lets them journal.
  def slack_connected? = slack_user_token.present?
  def slack_skipped? = slack_skipped_at.present?
  def slack_ready? = slack_connected? || slack_skipped?

  def skip_slack! = slack_skipped? || update!(slack_skipped_at: Time.current)

  def disconnect_slack! = update!(slack_user_token: nil, slack_user_token_scopes: nil)

  # Journals can pick a Lapse timelapse for their hours once Lapse is connected (LapseAuthController).
  def lapse_connected? = lapse_token.present?

  def disconnect_lapse! = update!(lapse_token: nil, lapse_synced_at: nil)

  def touch_last_seen
    update_column(:last_seen_at, Time.current) if last_seen_at.nil? || last_seen_at < 5.minutes.ago
  end

  # Signs a user in from an HCA authorization code: exchanges the code, loads the identity,
  # then creates or updates the local user. Slack profile details are refreshed in a background job.
  # `signup_source` (SignupSource) is kept only when this sign-in creates the account. A `trial` account signing in
  # becomes the HCA account: in place if it's new here, otherwise its projects and pet move over to the one there is.
  # One made by the Slack join button for their Slack ID counts as the one there is.
  def self.from_hca_code!(code, redirect_uri, signup_source: {}, trial: nil)
    token_data = HCA.exchange_code_for_token(code, redirect_uri)
    access_token = token_data&.dig("access_token")
    raise HCA::Error, "HCA did not return an access token" if access_token.blank?

    identity = HCA.identity(access_token)
    raise HCA::Error, "HCA did not return an identity" if identity.blank? || identity["id"].blank?

    user = find_by(hca_id: identity["id"]) || joined_from_slack(identity["slack_id"]) || trial || new
    user.hca_id = identity["id"]
    user.assign_from_hca(identity, access_token)
    user.signup_source = signup_source if user.new_record?
    transaction do
      user.save!
      trial.hand_over_to!(user) if trial && trial != user
    end
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

  def hand_over_to!(user)
    projects.update_all(user_id: user.id)
    user.update!(pet: pet) if user.pet.nil? && pet
    discard
  end

  # Pulls display name and timezone from the Slack workspace. Needs SLACK_BOT_TOKEN with users:read.
  def sync_slack_profile!
    return if slack_id.blank?

    info = SlackBot.client.users_info(user: slack_id)
    profile = info.user.profile
    updates = {}
    updates[:display_name] = profile.display_name.presence || profile.real_name.presence || display_name
    updates[:timezone] = info.user.tz if ActiveSupport::TimeZone[info.user.tz.to_s]
    update!(updates)
  end

  private

  def just_joined_fallen?
    return false if slack_id.blank? || pet.blank?

    (saved_change_to_pet? && pet_before_last_save.nil?) || (saved_change_to_slack_id? && slack_id_before_last_save.nil?)
  end

  def switching_pet? = will_save_change_to_pet? && pet_in_database.present? && pet.present?

  def pet_switch_allowed
    switch = pet_switch
    errors.add(:pet, "You can switch pets again on #{switch.resets_on.to_fs(:long)}.") unless switch.allowed?
  end

  def roles_are_known
    unknown = roles - ROLES
    errors.add(:roles, "contains unknown roles: #{unknown.join(', ')}") if unknown.any?
  end
end
