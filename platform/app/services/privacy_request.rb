# frozen_string_literal: true

# Deletes everything Fallen holds about one person, found only from a privacy hub token's subject.
# Dry runs and exports run the same deletion and roll it back, so the counts a reviewer approves are the
# counts the real run produces. What goes and what stays is written up in docs/privacy.md.
class PrivacyRequest
  BANNED_PLACEHOLDER = {
    email: "deleted@users.invalid",
    display_name: "Deleted user",
    avatar: nil,
    pet: nil,
    pet_switched_at: nil,
    slack_id: nil,
    hca_token: nil,
    slack_user_token: nil,
    slack_user_token_scopes: nil,
    slack_skipped_at: nil,
    lapse_token: nil,
    lapse_synced_at: nil,
    timezone: "UTC",
    verification_status: nil,
    is_adult: false,
    last_seen_at: nil,
    xp: 0,
    hatch_seen_at: nil,
    pronouns: nil,
    welcome_back_seen_at: nil,
    daily_goal_minutes: nil,
    signup_source: {}
  }.freeze

  def initialize(subject)
    @subject = subject
  end

  # Returns { found:, deleted:, retained: }. Changes are committed only when commit is true.
  def run(commit:)
    @commit = commit
    result = nil
    ActiveRecord::Base.transaction do
      result = delete_everything
      raise ActiveRecord::Rollback unless commit
    end
    result
  end

  private

  def commit? = @commit

  def delete_everything
    users = matching_users.lock.to_a
    @versions = 0
    rsvps = forget(WorkshopRsvp.where(email: subject_emails | users.map { it.email.downcase }))
    if users.empty?
      return { found: rsvps.positive?, deleted: { "workshop_rsvps" => rsvps, "versions" => @versions }.select { |_, count| count.positive? }, retained: [] }
    end

    ids = users.map(&:id)
    banned, removable = users.partition(&:is_banned?)
    deleted = {}
    retained = []

    @versions += PaperTrail::Version.where(item_type: "User", item_id: ids).delete_all
    deleted["workshop_rsvps"] = rsvps
    handed = hand_over_team_projects(ids)
    project_ids = Project.where(user_id: ids).pluck(:id)
    journal_ids = Journal.where(user_id: ids).or(Journal.where(project_id: project_ids)).pluck(:id)
    Journal.where(id: journal_ids).includes(images_attachments: :blob).find_each { |journal| journal.images.purge_later } if commit?
    Project.where(id: project_ids).with_attached_banner.find_each { |project| project.banner.purge_later } if commit?
    ActiveStorage::Attachment.where(record_type: "Journal", record_id: journal_ids).delete_all
    deleted["journal_drafts"] = forget(JournalDraft.where(user_id: ids).or(JournalDraft.where(project_id: project_ids)))
    ActiveStorage::Attachment.where(record_type: "Project", record_id: project_ids).delete_all
    deleted["xp_entries"] = forget(XpEntry.where(user_id: ids))
    deleted["streak_weeks"] = forget(StreakWeek.where(user_id: ids))
    deleted["streak_adjustments"] = forget(StreakAdjustment.where(user_id: ids))
    deleted["timezone_changes"] = forget(TimezoneChange.where(user_id: ids))
    deleted["huddle_sessions"] = forget(HuddleSession.where(user_id: ids).or(HuddleSession.where(slack_id: users.filter_map(&:slack_id))))
    deleted["huddle_events"] = forget(HuddleEvent.where(slack_id: users.filter_map(&:slack_id)))
    deleted["huddle_pauses"] = forget(HuddlePause.where(user_id: ids))
    deleted["timer_sessions"] = forget(TimerSession.where(user_id: ids))
    deleted["time_milestones"] = forget(TimeMilestone.where(user_id: ids))
    deleted["day_end_reminders"] = forget(DayEndReminder.where(user_id: ids))
    deleted["active_days"] = ActiveDay.where(user_id: ids).delete_all
    deleted["feature_flags"] = FeatureFlag.forget(users)
    deleted["lapse_timelapses"] = forget(LapseTimelapse.where(user_id: ids).or(LapseTimelapse.where(journal_id: journal_ids)))
    deleted["writing_checks"] = forget(WritingCheck.where(user_id: ids).or(WritingCheck.where(journal_id: journal_ids)))
    emails = users.map { it.email.downcase }
    deleted["project_transfers"] = forget(ProjectTransfer.where(user_id: ids).or(ProjectTransfer.where(project_id: project_ids)).or(ProjectTransfer.where(email: emails)))
    ProjectTransfer.where(reviewer_id: ids).update_all(reviewer_id: nil)
    ProjectTransfer.where(reached_out_by_id: ids).update_all(reached_out_by_id: nil)
    deleted.merge!(forget_submissions(ids, project_ids, journal_ids))
    deleted.merge!(forget_progress_reviews(ids, project_ids))
    deleted["journals"] = forget(Journal.where(id: journal_ids))
    deleted["project_members"] = forget(ProjectMember.where(user_id: ids).or(ProjectMember.where(project_id: project_ids)))
    deleted["project_invites"] = forget(ProjectInvite.where(user_id: ids).or(ProjectInvite.where(inviter_id: ids)).or(ProjectInvite.where(project_id: project_ids)))
    deleted["projects"] = forget(Project.where(id: project_ids))
    mcp_actions = McpAction.where(user_id: ids).or(McpAction.where(subject_type: "User", subject_id: ids))
    deleted["mcp_actions"] = mcp_actions.or(McpAction.where(subject_type: "Project", subject_id: project_ids)).delete_all
    deleted["mcp_sql_changes"] = McpSqlChange.where(user_id: ids).delete_all
    McpSqlChange.where(reviewer_id: ids).update_all(reviewer_id: nil)
    StreakAdjustment.where(admin_id: ids).update_all(admin_id: nil)
    StreakAdjustment.where(undone_by_id: ids).update_all(undone_by_id: nil)
    deleted["admin_tokens"] = forget(AdminToken.where(user_id: ids))
    deleted["users"] = User.where(id: removable.map(&:id)).delete_all
    deleted["versions"] = @versions

    attributed = PaperTrail::Version.where(whodunnit: ids.map(&:to_s)).update_all(whodunnit: nil)
    if attributed.positive?
      retained << { type: "versions", count: attributed,
                    reason: "history of changes this person made to other accounts as staff; kept for those accounts with the author removed" }
    end

    if handed.positive?
      retained << { type: "projects", count: handed,
                    reason: "projects other people are still building, handed to the teammate who joined first; this person's own journals on them are deleted" }
    end

    if banned.any?
      User.where(id: banned.map(&:id)).update_all(BANNED_PLACEHOLDER.merge(updated_at: Time.current))
      retained << { type: "banned users", count: banned.size,
                    reason: "kept as an anonymous placeholder holding only the Hack Club Auth id and ban flag, so the ban still applies if they sign in again; name, email, avatar, pet, Slack id and tokens are wiped" }
    end

    { found: true, deleted: deleted.select { |_, count| count.positive? }, retained: retained }
  end

  # Deletes the rows along with their change history, which is counted under "versions".
  # Design submissions of their projects or sent by them, with their parts lists, screenshots, reviews and funding,
  # and the repository reads behind them. Reviews and notes they wrote about other people's projects lose their name.
  def forget_submissions(ids, project_ids, journal_ids)
    submissions = Submission.where(user_id: ids).or(Submission.where(project_id: project_ids))
    submission_ids = submissions.pluck(:id)
    Submission.where(id: submission_ids).includes(:screenshots_attachments).find_each { |submission| submission.screenshots.purge_later } if commit?
    ActiveStorage::Attachment.where(record_type: "Submission", record_id: submission_ids).delete_all
    result = {
      "bom_items" => forget(BomItem.where(submission_id: submission_ids)),
      "journal_reviews" => forget(JournalReview.where(submission_id: submission_ids).or(JournalReview.where(journal_id: journal_ids))),
      "reviewer_notes" => forget(ReviewerNote.where(project_id: project_ids).or(ReviewerNote.where(submission_id: submission_ids))),
      "grant_payouts" => forget(GrantPayout.where(submission_id: submission_ids).or(GrantPayout.where(user_id: ids))),
      "hcb_grant_cards" => forget(HcbGrantCard.where(user_id: ids))
    }
    result["submissions"] = forget(Submission.where(id: submission_ids))
    snapshots = RepoSnapshot.where(user_id: ids).or(RepoSnapshot.where(project_id: project_ids))
    Submission.where(repo_snapshot_id: snapshots.select(:id)).update_all(repo_snapshot_id: nil)
    files = RepoFile.where(repo_snapshot_id: snapshots.select(:id))
    files.includes(:content_attachment).find_each { |file| file.content.purge_later } if commit?
    ActiveStorage::Attachment.where(record_type: "RepoFile", record_id: files.select(:id)).delete_all
    result["repo_files"] = forget(files)
    result["repo_snapshots"] = forget(snapshots)
    Submission.where(reviewer_id: ids).update_all(reviewer_id: nil)
    Submission.where(claimed_by_id: ids).update_all(claimed_by_id: nil, claim_expires_at: nil)
    Submission.where(review_draft_by_id: ids).update_all(review_draft_by_id: nil)
    JournalReview.where(reviewer_id: ids).update_all(reviewer_id: nil)
    ReviewerNote.where(user_id: ids).update_all(user_id: nil)
    GrantPayout.where(sent_by_id: ids).update_all(sent_by_id: nil)
    HcbConnection.where(connected_by_id: ids).delete_all
    result
  end

  # Journal reviews of their projects, what they asked them to fix, XP held back, and where those projects stand in
  # the queue. Reviews they wrote of other people's projects lose their name, as do the claims, AI flags, stars,
  # review requests and ticked to-dos they left.
  def forget_progress_reviews(ids, project_ids)
    result = {
      "review_todos" => forget(ReviewTodo.where(project_id: project_ids)),
      "progress_xp_holds" => forget(ProgressXpHold.where(project_id: project_ids).or(ProgressXpHold.where(user_id: ids))),
      "progress_reviews" => forget(ProgressReview.where(project_id: project_ids)),
      "progress_statuses" => forget(ProgressStatus.where(project_id: project_ids))
    }
    ProgressReview.where(reviewer_id: ids).update_all(reviewer_id: nil)
    ProgressStatus.where(claimed_by_id: ids).update_all(claimed_by_id: nil, claim_expires_at: nil)
    ProgressStatus.where(flagged_by_id: ids).update_all(flagged_by_id: nil)
    ProgressStatus.where(starred_by_id: ids).update_all(starred_by_id: nil)
    ProgressStatus.where(requested_by_id: ids).update_all(requested_by_id: nil)
    ProgressStatus.where(added_by_id: ids).update_all(added_by_id: nil)
    ReviewTodo.where(done_by_id: ids).update_all(done_by_id: nil)
    result
  end

  def forget(scope)
    ids = scope.pluck(:id)
    @versions += PaperTrail::Version.where(item_type: scope.model.name, item_id: ids).delete_all
    scope.model.where(id: ids).delete_all
  end

  # A project with someone else on its team goes to whoever joined it first, so their journals and its thread stay.
  # Returns how many were handed over.
  def hand_over_team_projects(ids)
    Project.where(user_id: ids).to_a.count do |project|
      successor = project.memberships.where.not(user_id: ids).first or next false
      forget(ProjectMember.where(id: successor.id))
      project.update_columns(user_id: successor.user_id)
    end
  end

  def subject_emails = Array(@subject["emails"]).grep(String).map(&:downcase)

  def matching_users
    scope = User.where("lower(email) IN (?)", subject_emails)
    scope = scope.or(User.where(slack_id: @subject["slack_id"])) if @subject["slack_id"].is_a?(String) && @subject["slack_id"].present?
    scope = scope.or(User.where(hca_id: @subject["identity_id"])) if @subject["identity_id"].is_a?(String) && @subject["identity_id"].present?
    scope
  end
end
