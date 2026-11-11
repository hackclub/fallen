# A project sent for review: for now its design, which a design reviewer approves for funding. It freezes what
# was sent (the RepoSnapshot, the screenshots, the bill of materials) so the reviewer judges that, whatever happens
# to the repo after. One review decides it (SubmissionReview): approved, returned for changes, or rejected for
# good. A returned project can be submitted again, which makes a new Submission.
# == Schema Information
#
# Table name: submissions
#
#  id                 :bigint           not null, primary key
#  approved_cents     :integer
#  bom_csv            :text
#  checks             :jsonb            not null
#  claim_expires_at   :datetime
#  commit_sha         :string
#  decided_at         :datetime
#  feedback           :text
#  flag_reason        :text
#  flagged_at         :datetime
#  internal_reason    :text
#  kind               :string           default("design"), not null
#  lock_version       :integer          default(0), not null
#  made_with          :string           default([]), not null, is an Array
#  note               :text
#  repo_url           :string           not null
#  requested_cents    :integer          default(0), not null
#  review_draft       :jsonb
#  review_draft_at    :datetime
#  rubric             :jsonb            not null
#  status             :string           default("pending"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  claimed_by_id      :bigint
#  project_id         :bigint           not null
#  repo_snapshot_id   :bigint
#  review_draft_by_id :bigint
#  reviewer_id        :bigint
#  user_id            :bigint           not null
#
# Indexes
#
#  index_submissions_on_claimed_by_id          (claimed_by_id)
#  index_submissions_on_project_id             (project_id)
#  index_submissions_on_repo_snapshot_id       (repo_snapshot_id)
#  index_submissions_on_review_draft_by_id     (review_draft_by_id)
#  index_submissions_on_reviewer_id            (reviewer_id)
#  index_submissions_on_status_and_created_at  (status,created_at)
#  index_submissions_on_user_id                (user_id)
#  index_submissions_one_pending_per_project   (project_id) UNIQUE WHERE ((status)::text = 'pending'::text)
#
# Foreign Keys
#
#  fk_rails_...  (claimed_by_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (repo_snapshot_id => repo_snapshots.id)
#  fk_rails_...  (review_draft_by_id => users.id)
#  fk_rails_...  (reviewer_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class Submission < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :sub
  has_paper_trail skip: %i[bom_csv checks]

  KINDS = %w[design].freeze
  STATUSES = %w[pending approved returned rejected withdrawn].freeze
  DECIDED = %w[approved returned rejected].freeze
  MAX_SCREENSHOTS = 5
  MAX_NOTE = 2_000
  # Written questions every reviewer answers the same way, so two reviews of one project can be compared.
  RUBRIC = {
    "complete" => "Is the design finished?",
    "works" => "Would it work as designed?",
    "original" => "Is it their own design, not a copied guide?",
    "documented" => "Could someone else build it from the repo and README?",
    "journals" => "Do the journals show the work it took?"
  }.freeze
  ANSWERS = %w[yes partly no].freeze

  belongs_to :project
  belongs_to :user
  belongs_to :repo_snapshot, optional: true
  belongs_to :reviewer, class_name: "User", optional: true
  belongs_to :claimed_by, class_name: "User", optional: true
  belongs_to :review_draft_by, class_name: "User", optional: true
  has_many :bom_items, -> { ordered }, dependent: :delete_all, inverse_of: :submission
  has_many :journal_reviews, dependent: :delete_all
  has_one :grant_payout, dependent: :restrict_with_error
  has_many_attached :screenshots

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :repo_url, presence: true
  validates :note, length: { maximum: MAX_NOTE }
  validates :feedback, :internal_reason, length: { maximum: 5_000 }
  validate :screenshots_are_images, if: -> { attachment_changes.key?("screenshots") }
  # Submitting ends journal review for a project that has had one, and withdrawing brings it back (ProgressStatus).
  after_commit -> { ProgressRefreshJob.perform_later(project_id) }, if: -> { previous_changes.key?("id") || previous_changes.key?("status") }

  scope :pending, -> { where(status: "pending") }
  scope :decided, -> { where(status: DECIDED) }
  scope :approved, -> { where(status: "approved") }
  scope :queued, -> { pending.where(flagged_at: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  STATUSES.each { |status| define_method(:"#{status}?") { self.status == status } }
  def decided? = status.in?(DECIDED)
  def requested_text = Money.format(requested_cents)
  def includes_part?(kind) = made_with.include?(kind)

  # Sends the project in, or returns an unsaved Submission whose errors say why not. `items` are BomItem attribute
  # hashes, `screenshots` signed blob ids.
  def self.submit(project:, user:, snapshot:, made_with:, note:, items:, screenshots:, bom_csv: nil)
    submission = new(project:, user:, repo_snapshot: snapshot, repo_url: snapshot&.url.to_s, commit_sha: snapshot&.commit_sha,
      made_with: Array(made_with).map(&:to_s) & SubmissionChecks::MADE_WITH, note: note.to_s.strip.presence,
      bom_csv: bom_csv.to_s.byteslice(0, BomImport::MAX_BYTES).presence)
    Array(items).first(BomItem::MAX_ITEMS).each_with_index do |attrs, i|
      submission.bom_items.build(attrs.to_h.symbolize_keys.slice(*BomItem::FIELDS).merge(position: i))
    end
    submission.screenshots.attach(Array(screenshots).first(MAX_SCREENSHOTS).compact_blank)
    submission.requested_cents = submission.bom_items.sum(&:requested_cents)
    submission.checks = SubmissionChecks.new(project:, snapshot:, made_with: submission.made_with,
      screenshots: submission.screenshots.attachments.size, items: submission.bom_items).run

    submission.refuse_unless_ready
    submission.save if submission.errors.empty?
    submission
  rescue ActiveRecord::RecordNotUnique
    submission.errors.add(:base, "This project is already waiting for review")
    submission
  end

  # The most an unfinished review can take, written out as JSON.
  MAX_DRAFT_BYTES = 200.kilobytes
  DRAFT_KEYS = %w[rubric journals bom feedback internal].freeze

  # Saves an unfinished review (SubmissionReview's fields as the review page holds them) for whoever holds the
  # submission, so leaving the page loses nothing and the next reviewer starts from it. False when they don't hold it
  # (someone else does, or it's decided), so a tab left open can't write over another reviewer's work.
  def save_review_draft(reviewer, data)
    data = data.to_h.stringify_keys.slice(*DRAFT_KEYS)
    return false if data.to_json.bytesize > MAX_DRAFT_BYTES

    Submission.pending.where(id:, claimed_by_id: reviewer.id).where(claim_expires_at: Time.current..)
      .update_all(review_draft: data, review_draft_at: Time.current, review_draft_by_id: reviewer.id, updated_at: Time.current) == 1
  end

  # Taken back by the person while it waits, so they can fix something. Nothing about it is kept for review.
  def withdraw!
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless pending?

      update!(status: "withdrawn", claimed_by: nil, claim_expires_at: nil)
    end
  end

  # The latest submission of each kind for a project page: what it shows as the project's status.
  def self.latest_for(project) = project.submissions.where.not(status: "withdrawn").newest_first.first

  def refuse_unless_ready
    errors.add(:base, "Only people on the team can submit this project") unless project.on_team?(user)
    errors.add(:base, "This project is already waiting for review") if Submission.pending.exists?(project:)
    errors.add(:base, "This design was already approved") if Submission.approved.exists?(project:, kind:)
    errors.add(:base, "This project was rejected, so it can't be submitted again") if Submission.where(project:, status: "rejected").exists?
    errors.add(:repo_url, "needs checking again: it was checked over #{RepoSnapshot::FRESH_FOR.inspect} ago") unless repo_snapshot&.project_id == project.id && repo_snapshot.fresh?
    errors.add(:note, "should say what you changed since the last review") if note.blank? && Submission.where(project:, status: "returned").exists?
    bom_items.each_with_index do |item, i|
      item.errors.full_messages.each { |message| errors.add(:bom_items, "row #{i + 1}: #{message}") } unless item.valid?
    end
    failed = checks.select { |check| check["status"] == "fail" }
    errors.add(:checks, failed.map { |check| check["detail"].delete("[]") }.join(" ")) if failed.any?
  end

  private

  def screenshots_are_images
    screenshots.attachments.select(&:new_record?).each do |attachment|
      blob = attachment.blob
      next errors.add(:screenshots, "must be PNG, JPEG, GIF or WebP images") unless blob.content_type.in?(Journal::IMAGE_TYPES)
      next errors.add(:screenshots, "must be under #{Journal::MAX_IMAGE_BYTES / 1.megabyte} MB") if blob.byte_size > Journal::MAX_IMAGE_BYTES

      uploader = blob.metadata[Journal::UPLOADER_KEY]
      teammates = project.teammates.map(&:id)
      # A resubmission may keep the screenshots of the one before it.
      earlier = ActiveStorage::Attachment.where(blob_id: blob.id, record_type: "Submission", record_id: Submission.where(project_id:).select(:id))
      elsewhere = ActiveStorage::Attachment.where(blob_id: blob.id).where.not(id: earlier.select(:id)).exists?
      errors.add(:screenshots, "must be images uploaded for this project") if elsewhere || (uploader && !uploader.in?(teammates))
    end
  end
end
