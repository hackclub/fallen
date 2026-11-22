# frozen_string_literal: true

# Everything the review page (/review/submissions/:id) shows, in a fixed number of queries whatever the size of the
# project: the submission, its project and team, every journal it covers with the evidence for its hours, the repo
# as it was submitted, earlier submissions of the same project and the reviewers' notes.
class ReviewPageProps
  def initialize(submission, reviewer:, claimed:, can:)
    @submission = submission
    @reviewer = reviewer
    @claimed = claimed
    @can = can
  end

  def props
    project = @submission.project
    Project.preload_teams([ project ])
    ActiveRecord::Associations::Preloader.new(records: [ @submission ], associations: [ :user, :reviewer, :claimed_by, *(:review_draft_by if @submission.review_draft_by_id), :bom_items, :grant_payout, :repo_snapshot, { screenshots_attachments: :blob } ]).call
    journals = SubmissionReview.journals_for(@submission).order(:created_at, :id).includes(:user, :xp_entry, :lapse_timelapses, images_attachments: :blob).to_a
    ids = journals.map(&:id)
    calls = if @submission.decided?
      @submission.journal_reviews.index_by(&:journal_id)
    else
      JournalReview.where(journal_id: ids).where.not(submission_id: @submission.id).order(:created_at, :id).index_by(&:journal_id)
    end
    history = project.submissions.where.not(id: @submission.id).where.not(status: "withdrawn").newest_first
      .includes(:user, :reviewer, :claimed_by, :bom_items, :grant_payout, screenshots_attachments: :blob).to_a

    {
      submission: ReviewSubmissionSerializer.render(@submission),
      project: {
        id: project.public_id, title: project.title, description: project.description, slack_url: project.slack_url,
        team: PersonSerializer.render(project.teammates), created_at: project.created_at,
        logged_minutes: journals.sum(&:duration_minutes), journal_count: journals.size
      },
      journals: ReviewJournalSerializer.render(journals, writing: writing_scores(ids), earlier: calls),
      repo: repo_props(@submission.repo_snapshot),
      history: ReviewSubmissionSerializer.render(history),
      notes: ReviewerNoteSerializer.render(project.reviewer_notes.includes(:user).order(:created_at, :id)),
      options: {
        rubric: Submission::RUBRIC, answers: Submission::ANSWERS, journal_reasons: JournalReview::REASONS
      },
      # An unfinished review someone left, to carry on from.
      draft: @submission.pending? && @submission.review_draft ? {
        data: @submission.review_draft, at: @submission.review_draft_at,
        by: @submission.review_draft_by && PersonSerializer.render(@submission.review_draft_by)
      } : nil,
      claimed: @claimed,
      can: @can
    }
  end

  private

  # The latest AI share Pangram gave each journal, by id.
  def writing_scores(ids) = WritingCheck.where(journal_id: ids, status: "done").order(:created_at, :id).pluck(:journal_id, :fraction_ai).to_h

  def repo_props(snapshot)
    return nil unless snapshot&.done?

    { url: snapshot.url, host: snapshot.host, branch: snapshot.branch, commit_sha: snapshot.commit_sha, paths: snapshot.paths,
      truncated: snapshot.tree_truncated, readme: snapshot.readme, readme_path: snapshot.readme_path, bom_path: snapshot.bom_path,
      bom_csv: snapshot.bom_csv, file_url_prefix: GitRemote.file_url(snapshot.url, snapshot.commit_sha, "") }
  end
end
