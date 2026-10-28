# A project someone started in another Hack Club program and asked to carry on here, on the transfer form linked
# from /transfers. The form writes to the Project Transfers table in Fallen's Airtable; SyncProjectTransfersJob copies
# each row here, matched to an account by email, and FetchProjectTransferJob reads the project from the program it
# came from into `snapshot` (Stardance, Fabricate, Macondo, Fallout, Forge, Stasis). Other programs have no fetcher,
# so a reviewer opens the link.
#
# Approving copies the snapshot's entries into a project as journals (source "transfer"), dated when they were
# written, with the hours the reviewer counts shared out over them in proportion to what each logged (evenly when none
# logged any, and one journal when there are no entries). The journals earn no XP themselves: the reviewer sets the
# XP, which is one "transfer" entry in the ledger, left out of the weekly team race.
# A row reviewed here keeps its decision even if the form's row changes; one still pending follows it. The person is
# DMed the decision, with the reviewer's `message` to them (ProjectTransferDecidedJob); `note` is for staff.
# == Schema Information
#
# Table name: project_transfers
#
#  id                 :bigint           not null, primary key
#  approved_minutes   :integer
#  claimed_minutes    :integer
#  decided_at         :datetime
#  discarded_at       :datetime
#  email              :string           not null
#  error              :text
#  fallen_project_url :string
#  fetched_at         :datetime
#  message            :text
#  name               :string
#  note               :text
#  project_name       :string
#  snapshot           :jsonb
#  source             :string
#  source_ref         :string
#  source_url         :string           not null
#  status             :string           default("pending"), not null
#  submitted_at       :datetime         not null
#  xp                 :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  airtable_id        :string           not null
#  project_id         :bigint
#  reviewer_id        :bigint
#  user_id            :bigint
#
# Indexes
#
#  index_project_transfers_on_airtable_id            (airtable_id) UNIQUE
#  index_project_transfers_on_discarded_at           (discarded_at)
#  index_project_transfers_on_email                  (email)
#  index_project_transfers_on_project_id             (project_id)
#  index_project_transfers_on_reviewer_id            (reviewer_id)
#  index_project_transfers_on_source_and_source_ref  (source,source_ref)
#  index_project_transfers_on_status                 (status)
#  index_project_transfers_on_submitted_at           (submitted_at)
#  index_project_transfers_on_user_id                (user_id)
#  index_project_transfers_unfetched                 (source) WHERE (fetched_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (reviewer_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class ProjectTransfer < ApplicationRecord
  include PublicIdentifiable
  include Discardable

  set_public_id_prefix :xfr
  has_paper_trail

  TABLE = "tblvlL0Mqg5owgKPm"
  FIELDS = {
    "fldKR9gNiifE4zT2q" => :email,
    "fldPplqwC36OTCyK5" => :first_name,
    "fldOjZ5cMhApjhFIr" => :last_name,
    "fldwsegfXB1OxQUzX" => :project_name,
    "fldzkCqgvi6ciRY9f" => :source_url,
    "fldN6Td9tKGU1jxCv" => :hours,
    "fldlbmugGwq1AVUzq" => :fallen_project_url
  }.freeze
  FETCHERS = { "stardance" => Stardance, "fabricate" => Fabricate, "macondo" => Macondo, "fallout" => Fallout, "forge" => Forge, "stasis" => Stasis }.freeze
  STATUSES = %w[pending approved rejected].freeze
  LINK = %r{\Ahttps?://\S+\z}
  EMBEDDED_IMAGE = /!\[[^\]]*\]\(\s*<?([^)\s>]+)>?[^)]*\)/
  # How a journal links a photo not copied onto it yet (CopyTransferPhotosJob), one to a line.
  PHOTO_LINK = /^\[Photo \d+\]\((\S+)\)$/
  # Images photos_apart can't move that Journal#embeds_only_own_photos refuses: HTML ones, and the `!` of
  # reference-style and empty ones.
  STRAY_IMAGE = /<img\b[^>]*>?|!(?=\[[^\]]*\][\[(])/i

  belongs_to :user, optional: true
  belongs_to :reviewer, class_name: "User", optional: true
  belongs_to :project, optional: true

  validates :airtable_id, :email, :source_url, :submitted_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :unfetched, -> { where(fetched_at: nil).where(source: FETCHERS.keys) }

  # Copies every row of the form's table, and drops pending ones whose row is gone. Returns how many rows it read.
  def self.sync
    records = Airtable.records(ENV.fetch("AIRTABLE_BASE_ID"), TABLE, fields: FIELDS.keys, whole: true)
    return 0 if records.empty?

    rows = records.map { |record| [ record, record["fields"].transform_keys(FIELDS) ] }
    emails = rows.filter_map { |_, fields| fields[:email].to_s.strip.downcase.presence }
    users = User.kept.where("lower(email) IN (?)", emails).index_by { it.email.downcase }
    existing = where(airtable_id: records.pluck("id")).index_by(&:airtable_id)

    rows.each { |record, fields| copy(existing[record["id"]] || new(airtable_id: record["id"]), record, fields, users) }
    kept.pending.where.not(airtable_id: records.pluck("id")).find_each(&:discard)
    records.size
  end

  def self.copy(transfer, record, fields, users)
    return unless transfer.pending?

    email = fields[:email].to_s.strip.downcase
    url = fields[:source_url].to_s.strip
    return if email.blank? || url.blank?

    source, ref = FETCHERS.lazy.filter_map { |name, fetcher| (ref = fetcher.ref_from(url)) && [ name, ref ] }.first
    transfer.assign_attributes(
      email: email,
      name: [ fields[:first_name], fields[:last_name] ].map { it.to_s.strip }.compact_blank.join(" ").presence,
      project_name: fields[:project_name].to_s.strip.presence,
      source_url: url,
      source: source,
      source_ref: ref,
      fallen_project_url: fields[:fallen_project_url].to_s.strip.presence,
      claimed_minutes: fields[:hours] && (fields[:hours].to_f * 60).round,
      submitted_at: record["createdTime"],
      user: users[email],
      discarded_at: nil
    )
    transfer.assign_attributes(snapshot: nil, fetched_at: nil, error: nil) if transfer.source_url_changed?
    transfer.save! if transfer.changed?
  end
  private_class_method :copy

  def pending? = status == "pending"
  def approved? = status == "approved"
  def fetchable? = FETCHERS.key?(source)
  def snapshot_minutes = snapshot&.dig("minutes")
  def airtable_url = "https://airtable.com/#{ENV['AIRTABLE_BASE_ID']}/#{TABLE}/#{airtable_id}"

  # The fewer of the hours the form claims and the hours the snapshot logged, as the reviewer's starting point. None
  # logged usually means the other program hides the entries (Stardance does until its author is verified).
  def suggested_minutes = [ claimed_minutes, snapshot_minutes&.nonzero? ].compact.min

  # Journal XP for those hours, before any streak multiplier.
  def self.suggested_xp(minutes) = minutes.to_i.positive? ? XpEntry.journal_xp(minutes, 1) : 0

  # Whether the account's Slack ID wrote the project in the program it came from. Unknown when that program
  # doesn't say (Fabricate, Fallout, Forge) or there is no account.
  def owner_check
    ids = Array(snapshot&.dig("author_slack_ids"))
    return nil if ids.empty? || user&.slack_id.blank?

    ids.include?(user.slack_id) ? "matches" : "differs"
  end

  # The project the form named, if it's one the person is on the team of.
  def named_project
    id = fallen_project_url.to_s[%r{/projects/(prj_\w+)}, 1]
    id && user && Project.teamed_with(user).kept.find_by_public_id(id)
  end

  def fetch!
    update!(snapshot: photos_apart(FETCHERS.fetch(source).project(source_ref)), error: nil, fetched_at: Time.current)
  rescue *FETCHERS.values.map { it::Error }, Faraday::Error, JSON::ParserError => e
    update!(error: e.message, fetched_at: Time.current)
  end

  def approve(reviewer:, minutes:, xp:, project: nil, note: nil, message: nil)
    minutes = Integer(minutes, exception: false)
    xp = Integer(xp, exception: false)
    errors.add(:base, "This transfer was already reviewed") unless pending?
    errors.add(:base, "No Fallen account has #{email}") if user.nil?
    errors.add(:approved_minutes, "must be more than zero") unless minutes&.positive?
    errors.add(:xp, "must be zero or more") unless xp && xp >= 0
    errors.add(:project, "must be a project #{user&.display_name} is on the team of") if project && (!project.on_team?(user) || project.discarded?)
    return false if errors.any?

    new_project = project.nil?
    # Locked so two reviewers (or a double submit) can't both approve it.
    journals = with_lock do
      errors.add(:base, "This transfer was already reviewed") unless pending?
      errors.add(:base, "This project was already transferred") if already_transferred?
      next if errors.any?

      project ||= user.projects.create!(project_attributes.merge(transferred: true))
      made = journal_attributes(minutes).map { project.journals.create!(it.merge(user: user, source: "transfer")) }
      user.xp_entries.create!(kind: "transfer", amount: xp, day: user.local_date, source: self) if xp.positive?
      update!(status: "approved", reviewer: reviewer, project: project, approved_minutes: minutes, xp: xp, note: note.presence, message: message.presence,
              decided_at: Time.current)
      made
    end
    return false unless journals

    ActiveJob.perform_all_later(journals.select { it.body.match?(PHOTO_LINK) }.map { CopyTransferPhotosJob.new(it) })
    ActiveJob.perform_all_later(project.teammates.map { ProjectTransferDecidedJob.new(self, new_project:, to: it) })
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, "Couldn't import the #{e.record.model_name.human.downcase}: #{e.record.errors.full_messages.to_sentence}")
    false
  end

  def reject(reviewer:, note: nil, message: nil)
    rejected = with_lock { pending? && update(status: "rejected", reviewer: reviewer, note: note.presence, message: message.presence, decided_at: Time.current) }
    return errors.add(:base, "This transfer was already reviewed") && false unless rejected

    ProjectTransferDecidedJob.perform_later(self)
    true
  end

  private

  def already_transferred?
    source_ref.present? && ProjectTransfer.kept.approved.where(source: source, source_ref: source_ref).where.not(id: id).exists?
  end

  def project_attributes
    {
      title: (snapshot&.dig("title").presence || project_name || "Transferred project").truncate(120),
      description: snapshot&.dig("description")&.truncate(5_000),
      repo_url: snapshot&.dig("repo_url").to_s[LINK],
      demo_url: snapshot&.dig("demo_url").to_s[LINK]
    }
  end

  def journal_attributes(minutes)
    entries = Array(snapshot&.dig("entries"))
    return [ { body: footer("#{project_name || 'Transferred project'}, from #{source_url}."), duration_minutes: minutes, created_at: submitted_at } ] if entries.empty?

    logged = entries.map { it["minutes"].to_i }
    logged = logged.map { 1 } if logged.sum.zero?

    entries.zip(share(logged, minutes)).map do |entry, share|
      written = Time.zone.parse(entry["at"].to_s) rescue nil
      { body: footer(entry_text(entry)), duration_minutes: share.nonzero?, created_at: written || submitted_at }
    end
  end

  # Splits `total` in proportion to `weights`, adding up to it exactly: rounded down, then the leftover minutes go to
  # the largest remainders.
  def share(weights, total)
    exact = weights.map { it * total.to_r / weights.sum }
    parts = exact.map(&:floor)
    exact.each_with_index.sort_by { |value, _| -(value - value.floor) }.first(total - parts.sum).each { |_, i| parts[i] += 1 }
    parts
  end

  # A journal shows only photos uploaded to it (Journal#embeds_only_own_photos), so the other program's start as links
  # and CopyTransferPhotosJob copies them on.
  def entry_text(entry)
    photos = Array(entry["images"]).each_with_index.map { |url, i| "[Photo #{i + 1}](#{url})" }.join("\n")
    [ entry["body"].to_s.gsub(STRAY_IMAGE, ""), photos ].compact_blank.join("\n\n").presence || "(No writing in this entry.)"
  end

  # Photos written into an entry's text go in its `images` with the rest, so the text is only writing.
  def photos_apart(project)
    project.merge("entries" => Array(project["entries"]).map do |entry|
      body = entry["body"].to_s
      entry.merge("body" => body.gsub(EMBEDDED_IMAGE, "").gsub(/\n{3,}/, "\n\n").strip, "images" => (Array(entry["images"]) + body.scan(EMBEDDED_IMAGE).flatten).uniq)
    end)
  end

  def footer(text)
    credit = "\n\n_Transferred from #{source_url}_"
    text.truncate(Journal::MAX_BODY_LENGTH - credit.length) + credit
  end
end
