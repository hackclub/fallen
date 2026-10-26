# One build. Anchored to a Slack thread in the journals channel: the top-level message is the project,
# every reply from someone on its team is a Journal. Projects started on the web get their anchor posted by
# PostProjectToSlackJob. The team is the owner plus its members (ProjectMember), who join through an invite or the
# project's link; each journals their own sessions and nothing they log is shared out.
# == Schema Information
#
# Table name: projects
#
#  id                  :bigint           not null, primary key
#  approved_at         :datetime
#  demo_url            :string
#  description         :text
#  discarded_at        :datetime
#  join_token          :string
#  repo_url            :string
#  slack_posted_by_bot :boolean          default(FALSE), not null
#  slack_thread_ts     :string
#  title               :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  slack_channel_id    :string
#  user_id             :bigint           not null
#
# Indexes
#
#  index_projects_on_discarded_at                          (discarded_at)
#  index_projects_on_join_token                            (join_token) UNIQUE
#  index_projects_on_slack_channel_id_and_slack_thread_ts  (slack_channel_id,slack_thread_ts) UNIQUE WHERE (slack_thread_ts IS NOT NULL)
#  index_projects_on_updated_at                            (updated_at)
#  index_projects_on_user_id                               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Project < ApplicationRecord
  include PublicIdentifiable
  include Discardable

  set_public_id_prefix :prj
  has_paper_trail
  has_secure_token :join_token, on: :create

  belongs_to :user
  has_many :journals, dependent: :destroy
  has_many :memberships, -> { order(:created_at, :id) }, class_name: "ProjectMember", dependent: :delete_all, inverse_of: :project
  has_many :invites, class_name: "ProjectInvite", dependent: :delete_all
  has_many :journal_drafts, dependent: :delete_all
  has_one_attached :banner

  BANNER_TYPES = Journal::IMAGE_TYPES
  MAX_BANNER_BYTES = Journal::MAX_IMAGE_BYTES
  # A first project started before this earns a bonus.
  EARLY_BIRD_UNTIL = ActiveSupport::TimeZone["America/New_York"].local(2026, 10, 17, 11, 59)
  EARLY_BIRD_BONUS = 20
  # People on one project, the owner included.
  MAX_TEAM = 4

  validates :title, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 5_000 }
  validates :repo_url, :demo_url, format: { with: %r{\Ahttps?://\S+\z}, message: "must be a link starting with http(s)://" }, allow_blank: true
  validates :slack_thread_ts, uniqueness: { scope: :slack_channel_id }, allow_nil: true
  validate :banner_is_an_image
  validate :banner_is_a_new_upload

  # Set by ProjectTransfer#approve: a project started in another program earns only the XP its reviewer sets.
  attr_accessor :transferred

  after_create :grant_early_bird, unless: :transferred

  scope :recent, -> { order(updated_at: :desc) }
  scope :approved, -> { where.not(approved_at: nil) }
  # The ones the person owns or is a member of.
  scope :teamed_with, ->(user) { where(user_id: user.id).or(where(id: ProjectMember.where(user_id: user.id).select(:project_id))) }
  # Those, plus any they left or were taken off but still have journals on, so their journals never go missing.
  scope :involving, ->(user) { teamed_with(user).or(where(id: Journal.kept.where(user_id: user.id).select(:project_id))) }

  def self.find_by_slack_thread(channel_id, thread_ts)
    return nil if channel_id.blank? || thread_ts.blank?

    kept.find_by(slack_channel_id: channel_id, slack_thread_ts: thread_ts)
  end

  # Minutes and journal counts per project id for a list, as ProjectSerializer's params.
  def self.journal_totals(projects)
    rows = Journal.kept.where(project_id: projects.map(&:id)).group(:project_id).pluck(:project_id, Arel.sql("COALESCE(SUM(duration_minutes), 0)"), Arel.sql("COUNT(*)"))
    { totals: rows.to_h { |id, minutes, _| [ id, minutes ] }, counts: rows.to_h { |id, _, count| [ id, count ] } }
  end

  # Loads the owners and members a list of projects shows, taking `known` people (the one looking) from memory,
  # since on someone's own list they are the owner of most of them.
  def self.preload_teams(projects, known: [])
    ActiveRecord::Associations::Preloader.new(records: projects, associations: [ :user, { memberships: :user } ], available_records: known).call
    projects
  end

  # Minutes and journal counts per author on one project, for its team panel.
  def totals_by_author
    journals.kept.group(:user_id).pluck(:user_id, Arel.sql("COALESCE(SUM(duration_minutes), 0)"), Arel.sql("COUNT(*)"))
      .to_h { |id, minutes, count| [ id, { minutes: minutes, journals: count } ] }
  end

  # The first photo of each project's newest logged journal, keyed by project id, for cards whose project has no
  # banner. Photos only count once their journal is saved: an upload still sitting in the composer is an unattached
  # blob, and a deleted journal's photos drop out.
  def self.journal_covers(projects)
    ActiveStorage::Attachment.where(record_type: "Journal", name: "images")
      .joins("INNER JOIN journals ON journals.id = active_storage_attachments.record_id")
      .where(journals: { project_id: projects.map(&:id), discarded_at: nil })
      .select("DISTINCT ON (journals.project_id) active_storage_attachments.*, journals.project_id AS cover_project_id")
      .order(Arel.sql("journals.project_id, journals.created_at DESC, journals.id DESC, active_storage_attachments.id"))
      .includes(:blob)
      .index_by(&:cover_project_id)
  end

  # Owner first, then members in the order they joined.
  def teammates = [ user, *memberships.map(&:user) ]
  def on_team?(person) = person.present? && (user_id == person.id || memberships.any? { |member| member.user_id == person.id })
  def solo? = memberships.none?
  # Counting only who has joined: a membership being added sits in `memberships` before it is saved.
  def team_full? = 1 + joined_count >= MAX_TEAM
  # Places a new invite may take: pending invites hold theirs, so someone invited is not turned away once they accept.
  def open_seats(waiting = invites.size) = [ MAX_TEAM - 1 - joined_count - waiting, 0 ].max

  # The link anyone can join with, made the first time a teammate opens the invite panel.
  def join_token!
    update_column(:join_token, self.class.generate_unique_secure_token) if join_token.nil?
    join_token
  end

  # The owner leaving hands the project to whoever joined first; a member leaving, or being taken off, just goes.
  # Their journals stay on the project and stay theirs.
  def remove_teammate(person)
    return memberships.find_by!(user: person).destroy! unless person.id == user_id

    successor = memberships.first or raise ActiveRecord::RecordNotFound, "No one to hand #{public_id} to"
    transaction do
      successor.destroy!
      update!(user: successor.user)
    end
  end

  def slack_linked? = slack_channel_id.present? && slack_thread_ts.present?

  # Staff mark the finished project as working (Admin::ProjectsController), which the final evolution needs.
  def approved? = approved_at.present?

  def approved=(value)
    self.approved_at = ActiveModel::Type::Boolean.new.cast(value) ? (approved_at || Time.current) : nil
  end

  def slack_url = slack_linked? ? SlackMessaging.permalink(slack_channel_id, slack_thread_ts) : nil

  def total_minutes = journals.kept.sum(:duration_minutes)

  def journal_count = journals.kept.count

  # Takes back the XP it brought: its journals' and the early-bird bonus.
  def discard
    transaction do
      journals.kept.includes(images_attachments: :blob).find_each(&:discard)
      XpEntry.kept.where(source: self).find_each(&:discard)
      super
    end
  end

  private

  def joined_count = memberships.count(&:persisted?)

  def grant_early_bird
    return if created_at > EARLY_BIRD_UNTIL || user.xp_entries.kept.exists?(kind: "early_bird")

    user.xp_entries.create!(kind: "early_bird", amount: EARLY_BIRD_BONUS, day: user.local_date(created_at), source: self)
  end

  def banner_is_a_new_upload
    return unless banner.attachment&.new_record?

    uploaders = [ user_id, *memberships.map(&:user_id) ]
    errors.add(:banner, "must be an image uploaded for this project") if Journal.reused_uploads?([ banner.attachment.blob ], uploaders:, record: self)
  end

  def banner_is_an_image
    blob = banner.attachment&.blob
    return if blob.nil?

    errors.add(:banner, "must be a PNG, JPEG, GIF or WebP") unless blob.content_type.in?(BANNER_TYPES)
    errors.add(:banner, "must be under #{MAX_BANNER_BYTES / 1.megabyte} MB") if blob.byte_size > MAX_BANNER_BYTES
  end
end
