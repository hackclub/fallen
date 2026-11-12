# A repository as it was when someone checked it from the submit popup (GitRemote does the reading, in
# RepoSnapshotJob). A Submission keeps the one it was made from, so reviewers read what was submitted even after
# the repo changes or goes away.
# == Schema Information
#
# Table name: repo_snapshots
#
#  id             :bigint           not null, primary key
#  bom_csv        :text
#  bom_import     :jsonb
#  bom_path       :string
#  branch         :string
#  commit_sha     :string
#  error          :text
#  fetched_at     :datetime
#  host           :string
#  readme         :text
#  readme_path    :string
#  status         :string           default("pending"), not null
#  tree           :jsonb            not null
#  tree_truncated :boolean          default(FALSE), not null
#  url            :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  project_id     :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_repo_snapshots_on_project_id  (project_id)
#  index_repo_snapshots_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class RepoSnapshot < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :rps
  has_paper_trail skip: %i[tree readme bom_csv bom_import]

  STATUSES = %w[pending done failed].freeze
  # A submission has to use a check this recent, so what's reviewed is what's in the repo.
  FRESH_FOR = 2.hours
  # Checks one person can start in an hour, so the popup can't be used to make us hammer someone's server.
  PER_HOUR = 30

  belongs_to :project
  belongs_to :user
  has_many :repo_files, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :url, presence: true

  after_create_commit -> { RepoSnapshotJob.perform_later(self) }

  def self.start(project:, user:, url:)
    url = GitRemote.normalize(url)
    return :throttled if where(user:).where(created_at: 1.hour.ago..).count >= PER_HOUR

    create!(project:, user:, url:)
  end

  def pending? = status == "pending"
  def done? = status == "done"
  def failed? = status == "failed"
  def fresh? = done? && fetched_at && fetched_at > FRESH_FOR.ago

  def fetch!
    data = GitRemote.snapshot(url)
    update!(status: "done", fetched_at: Time.current, error: nil, **data.to_h.except(:url))
    BomExtractionJob.perform_later(self) if bom_csv.present?
  rescue GitRemote::Error => e
    update!(status: "failed", fetched_at: Time.current, error: e.message)
  end

  # Whether its bom.csv has been read into parts rows yet: "none" when the repo has no bom.csv.
  def bom_state
    return "none" unless done? && bom_csv.present?

    bom_import ? "done" : "pending"
  end

  # Queues the read again for a check whose read never happened (one made before reads existed, or a job that was
  # lost). The popup polls every couple of seconds while it waits, so this queues at most one every few minutes.
  def read_bom_later
    return unless bom_state == "pending" && fetched_at && fetched_at < 2.minutes.ago
    return unless Rails.cache.write("repo_snapshot_bom:#{id}", true, unless_exist: true, expires_in: 5.minutes)

    BomExtractionJob.perform_later(self)
  end

  # Checking the repo again without touching bom.csv reuses the last reading of it instead of paying for another.
  def read_bom!
    earlier = RepoSnapshot.where(project_id:).where.not(id:).where.not(bom_import: nil).where(bom_csv:).order(id: :desc).pick(:bom_import)
    return update!(bom_import: earlier) if earlier

    result = BomExtraction.read(bom_csv)
    update!(bom_import: { "items" => result.items.map(&:to_h), "warnings" => result.warnings, "stated_total_cents" => result.stated_total_cents, "source" => result.source })
  end

  # The parts its bom.csv was read into, as BomImport::Items (empty until it has been read).
  def bom_items = bom_import.to_h.fetch("items", []).map { |item| BomImport::Item.new(**item.symbolize_keys) }

  def paths = tree.filter_map { |entry| entry["path"] if entry["type"] == "blob" }
  def file_url(path) = GitRemote.file_url(url, commit_sha, path)
end
