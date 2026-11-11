require "test_helper"

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
class SubmissionTest < ActiveSupport::TestCase
  include FixtureHelper

  test "submitting freezes what was sent and runs the checks" do
    submission = submit_design(projects(:station))

    assert submission.persisted?, submission.errors.full_messages.to_sentence
    assert submission.pending?
    assert_equal "a" * 40, submission.commit_sha
    assert_equal 700, submission.requested_cents
    assert_equal %w[RP2040 Shipping], submission.bom_items.map(&:name)
    assert_equal 1, submission.screenshots.count
    assert_includes submission.checks.map { it["key"] }, "pcb_source"
    refute SubmissionChecks.blocking?(submission.checks)
  end

  test "a failed check, a stale repository check, or a second submission is refused" do
    project = projects(:station)
    project.journals.kept.needing_hours.update_all(duration_minutes: 30)
    snapshot = read_snapshot(project)

    failing = Submission.submit(project:, user: project.user, snapshot:, made_with: %w[cad], note: nil, items: bom_rows, screenshots: [])
    refute failing.persisted?
    assert_match "screenshot", failing.errors[:checks].join
    assert_match(/step/i, failing.errors[:checks].join)

    snapshot.update!(fetched_at: 3.hours.ago)
    stale = Submission.submit(project:, user: project.user, snapshot:, made_with: [], note: nil, items: bom_rows, screenshots: [])
    assert stale.errors[:repo_url].any?

    assert submit_design(project).persisted?
    again = submit_design(project)
    assert_match "already waiting", again.errors[:base].join
  end

  test "only the team submits, and a resubmission says what changed" do
    project = projects(:station)
    outsider = Submission.submit(project:, user: users(:newcomer), snapshot: read_snapshot(project), made_with: [], note: nil, items: bom_rows, screenshots: [])
    assert_match "Only people on the team", outsider.errors[:base].join

    first = submit_design(project)
    first.update!(status: "returned")
    second = submit_design(project)
    assert_match "what you changed", second.errors[:note].join
  end

  test "an empty bom.csv in the repo is a warning, not a pass" do
    project = projects(:station)
    project.journals.kept.needing_hours.update_all(duration_minutes: 30)
    snapshot = read_snapshot(project)
    snapshot.update!(bom_csv: "")
    check = SubmissionChecks.new(project:, snapshot:, made_with: [], screenshots: 1, items: bom_rows.map { BomItem.new(it) }).run.find { it["key"] == "repo_bom" }

    assert_equal "warn", check["status"]
    assert_match "is empty", check["detail"]
  end

  test "a project with no journal hours fails with a link to the start-here docs, sent without the link brackets" do
    project = projects(:station)
    project.journals.kept.update_all(discarded_at: Time.current)
    check = SubmissionChecks.new(project:, snapshot: read_snapshot(project), made_with: [], screenshots: 1, items: bom_rows.map { BomItem.new(it) }).run.find { it["key"] == "journals" }

    assert_equal [ "fail", "start-here" ], check.values_at("status", "doc")
    assert_match "[here]", check["detail"]

    refused = submit_design(project)
    assert_match "Learn more here!", refused.errors[:checks].join
    assert_no_match(/\[|\]/, refused.errors[:checks].join)
  end

  test "a bad parts list is refused row by row" do
    project = projects(:station)
    project.journals.kept.needing_hours.update_all(duration_minutes: 30)
    items = [ { kind: "part", name: "", quantity: 1, total_cents: 100, link: "javascript:alert(1)" } ]
    submission = Submission.submit(project:, user: project.user, snapshot: read_snapshot(project), made_with: [], note: nil, items:, screenshots: [])

    assert_match "row 1", submission.errors[:bom_items].join
  end

  test "screenshots must be uploaded by the team" do
    project = projects(:station)
    stranger = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("png"), filename: "x.png", content_type: "image/png", metadata: { Journal::UPLOADER_KEY => users(:newcomer).id })
    project.journals.kept.needing_hours.update_all(duration_minutes: 30)
    submission = Submission.submit(project:, user: project.user, snapshot: read_snapshot(project), made_with: [], note: nil, items: bom_rows, screenshots: [ stranger.signed_id ])

    assert_match "uploaded for this project", submission.errors[:screenshots].join
  end

  test "taking it back while it waits" do
    submission = submit_design(projects(:station))
    submission.withdraw!

    assert submission.withdrawn?
    assert_nil Submission.latest_for(projects(:station))
    assert_raises(ActiveRecord::RecordInvalid) { submission.withdraw! }
  end

  test "journals can't move out of a project waiting for review" do
    project = projects(:station)
    submit_design(project)
    project.memberships.create!(user: users(:admin))
    journal = journals(:first)

    refute journal.move_to(projects(:unlinked))
    assert_match "waiting for review", journal.errors[:base].join
  end
end
