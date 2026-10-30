require "test_helper"

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
class ProjectTransferTest < ActiveSupport::TestCase
  test "sync copies the form's rows, matches accounts by email and reads the program from the link" do
    rows = [
      record("recNEW", email: " Member@Example.com", source_url: "https://fabricate.hackclub.com/projects/333", hours: 1.5, first_name: "Mem", last_name: "Ber"),
      record("recOTHER", email: "nobody@example.com", source_url: "https://blueprint.hackclub.com/projects/3740"),
      record("recBLANK", email: "", source_url: "https://stardance.hackclub.com/projects/1")
    ]
    count = sync(rows)

    assert_equal 3, count
    fabricate = ProjectTransfer.find_by!(airtable_id: "recNEW")
    assert_equal [ users(:member), "fabricate", "333", 90, "Mem Ber" ], fabricate.values_at(:user, :source, :source_ref, :claimed_minutes, :name)
    assert_equal Time.utc(2026, 10, 21, 18, 24, 3), fabricate.submitted_at
    other = ProjectTransfer.find_by!(airtable_id: "recOTHER")
    assert_equal [ nil, nil ], [ other.user, other.source ]
    assert_not ProjectTransfer.exists?(airtable_id: "recBLANK")
    assert project_transfers(:stardance).reload.discarded?, "a pending row gone from the form is dropped"
  end

  test "sync leaves reviewed transfers as they were decided, and fetches again when the link changes" do
    project_transfers(:stranger).update!(status: "rejected")
    rows = [
      record("recSTRANGER", email: "changed@example.com", source_url: "https://macondo.hackclub.com/projects/1"),
      record("recSTARDANCE", email: "member@example.com", source_url: "https://stardance.hackclub.com/projects/999")
    ]
    sync(rows)

    assert_equal "stranger@example.com", project_transfers(:stranger).reload.email
    moved = project_transfers(:stardance).reload
    assert_equal [ "999", nil, nil ], [ moved.source_ref, moved.snapshot, moved.fetched_at ]
  end

  test "an empty table changes nothing" do
    assert_equal 0, sync([])
    assert project_transfers(:stardance).reload.kept?
  end

  test "a failed fetch keeps the reason and the earlier snapshot" do
    transfer = project_transfers(:stardance)
    original = Stardance.method(:project)
    Stardance.define_singleton_method(:project) { |_| raise Stardance::Error, "Stardance has no project 22328" }
    transfer.fetch!

    assert_equal "Stardance has no project 22328", transfer.reload.error
    assert_equal "Hexapod robot", transfer.snapshot["title"]
  ensure
    Stardance.define_singleton_method(:project, original)
  end

  test "suggests the fewer of the claimed and logged hours, ignoring a program that showed none" do
    transfer = project_transfers(:stardance)
    assert_equal 180, transfer.suggested_minutes
    transfer.snapshot = transfer.snapshot.merge("minutes" => 0)
    assert_equal 240, transfer.suggested_minutes
    assert_equal 600, project_transfers(:stranger).suggested_minutes
  end

  test "owner check compares the account's Slack ID with the project's authors" do
    transfer = project_transfers(:stardance)
    assert_equal "matches", transfer.owner_check
    transfer.snapshot = transfer.snapshot.merge("author_slack_ids" => [ "U0SOMEONE" ])
    assert_equal "differs", transfer.owner_check
    assert_nil project_transfers(:stranger).owner_check
  end

  test "approving imports each entry as a journal dated when it was written, and issues the XP set" do
    transfer = project_transfers(:stardance)
    xp_before = users(:member).xp

    assert transfer.approve(reviewer: users(:admin), minutes: 90, xp: 12, note: "Deflated")
    transfer.reload
    project = transfer.project
    assert_equal [ "Hexapod robot", "https://github.com/example/hexapod", users(:member) ], [ project.title, project.repo_url, project.user ]
    journals = project.journals.order(:created_at)
    assert_equal [ 30, 60 ], journals.map(&:duration_minutes), "90 minutes shared out in proportion to 60 and 120"
    assert_equal Time.utc(2026, 7, 17, 0, 2, 58), journals.first.created_at
    assert_equal %w[transfer transfer], journals.map(&:source)
    assert_includes journals.first.body, "[Photo 1](https://stardance.hackclub.com/rails/active_storage/leg.webp)"
    assert_includes journals.first.body, "Transferred from https://stardance.hackclub.com/projects/22328"
    assert journals.all? { it.xp_entry.nil? }, "transferred journals earn no XP of their own"

    assert_equal [ "approved", users(:admin), 90, 12, "Deflated" ], transfer.values_at(:status, :reviewer, :approved_minutes, :xp, :note)
    assert_equal xp_before + 12, users(:member).reload.xp
    entry = users(:member).xp_entries.find_by!(kind: "transfer")
    assert_equal [ 12, transfer ], [ entry.amount, entry.source ]
    assert_not XpEntry.raced_in(Week.racing).exists?(kind: "transfer"), "left out of the team race"
  end

  test "approving shares the hours evenly when no entry logged any" do
    transfer = project_transfers(:stardance)
    transfer.update!(snapshot: transfer.snapshot.merge("entries" => transfer.snapshot["entries"].map { it.merge("minutes" => 0) }))

    assert transfer.approve(reviewer: users(:admin), minutes: 90, xp: 0)
    assert_equal [ 45, 45 ], transfer.project.journals.order(:created_at).map(&:duration_minutes)
  end

  test "approving without entries makes one journal and can add to an existing project" do
    transfer = project_transfers(:stardance)
    transfer.update!(snapshot: nil)

    assert transfer.approve(reviewer: users(:admin), minutes: 40 * 60, xp: 0, project: projects(:station))
    journal = projects(:station).journals.find_by!(source: "transfer")
    assert_equal [ 2400, transfer.submitted_at ], [ journal.duration_minutes, journal.created_at ]
    assert_not users(:member).xp_entries.exists?(kind: "transfer"), "no XP entry for zero XP"
  end

  test "journals written in share the hours, need writing or photos, and take the place of the one journal" do
    transfer = project_transfers(:stardance)
    transfer.update!(snapshot: nil)
    image = photo("board.png").tap { it.update!(metadata: it.metadata.merge(Journal::UPLOADER_KEY => users(:admin).id)) }
    journals = [
      { body: "Made a hairpin ![board.png](/rails/active_storage/blobs/redirect/#{image.signed_id}/board.png)", date: "2026-10-20", images: [ image.signed_id ] },
      { body: "", date: "2026-10-21", images: [] },
      { body: "Named it", date: "" }
    ]

    assert transfer.approve(reviewer: users(:admin), minutes: 8 * 60, xp: 40, journals:), transfer.errors.full_messages.to_sentence
    first, second = transfer.project.journals.order(:created_at, :id)
    assert_equal 2, transfer.project.journals.count, "the blank one is skipped and no placeholder is made"
    assert_equal [ 240, Time.zone.parse("2026-10-20 12:00"), [ image ] ], [ first.duration_minutes, first.created_at, first.images.blobs.to_a ]
    assert_equal [ 240, transfer.submitted_at ], [ second.duration_minutes, second.created_at ]
    assert second.body.start_with?("Named it")
    assert transfer.project.journals.all? { it.transferred? && it.xp_entry.nil? }
    assert_equal [ 480, 40 ], transfer.reload.values_at(:approved_minutes, :xp)
    assert_equal 480, transfer.project.total_minutes
  end

  test "journals written in share the hours with fetched entries, each counted as an average entry" do
    transfer = project_transfers(:stardance)

    assert transfer.approve(reviewer: users(:admin), minutes: 90, xp: 0, journals: [ { body: "Extra" } ])
    assert_equal [ 20, 40, 30 ], transfer.project.journals.order(:id).map(&:duration_minutes)
    assert_equal 90, transfer.project.total_minutes
  end

  test "journals written in with a bad date import nothing" do
    transfer = project_transfers(:stardance)

    assert_not transfer.approve(reviewer: users(:admin), minutes: 60, xp: 0, journals: [ { body: "x", date: "soon" } ])
    assert_equal [ "1: the date isn't one" ], transfer.errors[:journals]
    assert transfer.reload.pending?
    assert_equal 0, Journal.where(source: "transfer").count
  end

  test "approving can add to a project the person is a member of, not only one they own" do
    transfer = project_transfers(:stardance)
    transfer.update!(snapshot: nil, fallen_project_url: "https://fallen.hackclub.com/projects/#{projects(:admins).public_id}")
    assert_nil transfer.named_project, "not on its team yet"
    projects(:admins).memberships.create!(user: users(:member))

    assert_equal projects(:admins), transfer.reload.named_project
    assert transfer.approve(reviewer: users(:admin), minutes: 60, xp: 0, project: projects(:admins))
    assert_equal users(:member), projects(:admins).journals.find_by!(source: "transfer").user
  end

  test "approving refuses what can't be imported" do
    stranger = project_transfers(:stranger)
    assert_not stranger.approve(reviewer: users(:admin), minutes: 60, xp: 8)
    assert_includes stranger.errors[:base], "No Fallen account has stranger@example.com"

    transfer = project_transfers(:stardance)
    assert_not transfer.approve(reviewer: users(:admin), minutes: 0, xp: -1, project: projects(:station).tap { it.user = users(:admin) })
    assert transfer.errors.key?(:approved_minutes)
    assert transfer.errors.key?(:xp)
    assert transfer.errors.key?(:project)
    assert_equal 0, Journal.where(source: "transfer").count
  end

  test "the same project can't be transferred twice" do
    assert project_transfers(:stardance).approve(reviewer: users(:admin), minutes: 60, xp: 8)
    again = ProjectTransfer.create!(airtable_id: "recAGAIN", user: users(:member), email: "member@example.com", source_url: "https://stardance.hackclub.com/projects/22328",
                                    source: "stardance", source_ref: "22328", submitted_at: Time.current)

    assert_not again.approve(reviewer: users(:admin), minutes: 60, xp: 8)
    assert_includes again.errors[:base], "This project was already transferred"
    assert again.reject(reviewer: users(:admin), note: "Duplicate")
    assert_equal [ "rejected", "Duplicate" ], again.reload.values_at(:status, :note)
    assert_not again.reject(reviewer: users(:admin)), "a decision is made once"
  end

  test "a transfer approved twice at once is imported once" do
    first = project_transfers(:stardance)
    second = ProjectTransfer.find(first.id)

    assert first.approve(reviewer: users(:admin), minutes: 60, xp: 8)
    assert_not second.approve(reviewer: users(:admin), minutes: 60, xp: 8)
    assert_includes second.errors[:base], "This transfer was already reviewed"
    assert_equal 2, Journal.where(source: "transfer").count
    assert_equal 1, users(:member).xp_entries.where(kind: "transfer").count
  end

  test "approving keeps journals valid whatever the other program wrote" do
    transfer = project_transfers(:stardance)
    entries = [
      { "at" => "2026-07-17T00:02:58Z", "minutes" => 60, "body" => "Wired <img src=\"https://x.test/a.png\"> and ![logo][1] and ![]()", "images" => [] },
      { "at" => "2026-07-18T00:00:00Z", "minutes" => 60, "body" => "x" * 20_000, "images" => [] }
    ]
    transfer.update!(snapshot: transfer.snapshot.merge("entries" => entries), source_url: "https://stardance.hackclub.com/projects/22328?#{'q' * 200}")

    assert transfer.approve(reviewer: users(:admin), minutes: 120, xp: 0), transfer.errors.full_messages.to_sentence
    first, second = transfer.project.journals.order(:created_at)
    assert_includes first.body, "Wired  and [logo][1] and []()"
    assert_operator second.body.length, :<=, Journal::MAX_BODY_LENGTH
    assert second.body.end_with?("#{'q' * 200}_")
  end

  test "a journal that can't be imported is a form error, and nothing is kept" do
    transfer = project_transfers(:stardance)
    original = Journal.instance_method(:embeds_only_own_photos)
    Journal.define_method(:embeds_only_own_photos) { errors.add(:body, "is wrong") }

    assert_not transfer.approve(reviewer: users(:admin), minutes: 60, xp: 8)
    assert_includes transfer.errors[:base], "Couldn't import the journal: Body is wrong"
    assert transfer.reload.pending?
    assert_equal 0, Journal.where(source: "transfer").count
    assert_not users(:member).xp_entries.exists?(kind: "transfer")
  ensure
    Journal.define_method(:embeds_only_own_photos, original)
  end

  test "entries given no share of the hours don't count as missing hours, and the project earns no early bird" do
    transfer = project_transfers(:stardance)
    entries = Array.new(4) { |i| { "at" => "2026-07-1#{i}T00:00:00Z", "minutes" => 60, "body" => "Day #{i}", "images" => [] } }
    transfer.update!(snapshot: transfer.snapshot.merge("entries" => entries))

    travel_to Project::EARLY_BIRD_UNTIL - 1.day do
      assert transfer.approve(reviewer: users(:admin), minutes: 2, xp: 0)
    end
    journals = transfer.project.journals
    assert_equal 2, journals.where(duration_minutes: nil).count
    assert_not journals.needing_hours.exists?
    assert_not users(:member).xp_entries.exists?(kind: "early_bird", source: transfer.project)
  end

  private

  def sync(rows) = stub_method(Airtable, :records, rows) { with_env("AIRTABLE_BASE_ID" => "appTEST") { ProjectTransfer.sync } }

  def record(id, email:, source_url:, hours: nil, first_name: nil, last_name: nil)
    fields = { email: email, source_url: source_url, hours: hours, first_name: first_name, last_name: last_name }.compact
    { "id" => id, "createdTime" => "2026-10-21T18:24:03.000Z", "fields" => fields.transform_keys(ProjectTransfer::FIELDS.invert) }
  end
end
