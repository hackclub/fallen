require "test_helper"

class JournalReviewTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @project = projects(:station)
    @project.journals.kept.update_all(duration_minutes: ProgressStatus::FIRST_AT_MINUTES)
    @status = ProgressStatus.refresh(@project)
    @reviewer = users(:newcomer)
    @reviewer.update!(roles: %w[user reviewer])
  end

  def decision(verdict: "approved", feedback: "Great photos")
    { review: { verdict:, feedback: } }
  end

  test "people without the role don't see the queue, design reviewers included" do
    sign_in_as users(:member)
    get journal_review_root_path
    assert_response :not_found

    users(:member).update!(roles: %w[user design_reviewer])
    get journal_review_root_path
    assert_response :not_found
    get starred_projects_path
    assert_response :not_found
  end

  test "a reviewer works the queue: next claims it, the page shows the journals, deciding posts the feedback" do
    sign_in_as @reviewer
    rows = load_deferred(journal_review_root_path, "Review/Progress/Index", "projects", "pagy", "counts")
    assert_equal [ @project.public_id ], rows["projects"].pluck("id")
    assert_equal({ "first" => 1 }, rows["counts"]["by_reason"])

    get journal_review_next_path
    assert_redirected_to journal_review_project_path(@project)
    assert_equal @reviewer.id, @status.reload.claimed_by_id

    props = inertia_props(journal_review_project_path(@project), "Review/Progress/Show")
    assert props["claimed"]
    assert props["can"]["decide"]
    refute props["can"]["dismiss"]
    assert_equal @project.journals.kept.count, props["journals"].size

    post heartbeat_journal_review_project_path(@project), as: :json
    assert response.parsed_body["held"]

    assert_enqueued_with(job: ProgressReviewedJob) { patch journal_review_project_path(@project), params: decision }
    assert_redirected_to journal_review_next_path
    review = @project.progress_reviews.sole
    assert_equal [ "approved", @reviewer ], [ review.verdict, review.reviewer ]
    refute @status.reload.due?

    rows = load_deferred(journal_review_projects_path(tab: "mine"), "Review/Progress/Index", "reviews", "pagy")
    assert_equal [ review.public_id ], rows["reviews"].pluck("id")

    sign_in_as users(:member)
    props = load_deferred(project_path(@project), "Projects/Show", "journal_review")
    assert_equal [ "Great photos" ], props["journal_review"]["reviews"].pluck("feedback")
  end

  test "a check back without feedback comes back with errors" do
    sign_in_as @reviewer
    get journal_review_project_path(@project)
    patch journal_review_project_path(@project), params: decision(verdict: "check_back", feedback: ""), headers: { "HTTP_REFERER" => journal_review_project_path(@project) }
    assert_empty @project.progress_reviews
    assert @status.reload.due?
  end

  test "skipping lets it go, flagging for AI takes it out of the queue, starring lists it" do
    sign_in_as @reviewer
    get journal_review_next_path
    post release_journal_review_project_path(@project)
    assert_nil @status.reload.claimed_by_id
    assert_redirected_to journal_review_next_path(skip: @project.public_id)

    post star_journal_review_project_path(@project)
    rows = load_deferred(starred_projects_path, "Review/MarkedProjects/Index", "projects", "pagy")
    assert_equal [ @project.public_id ], rows["projects"].pluck("id")

    get journal_review_project_path(@project)
    other = users(:admin)
    @status.update!(flagged_at: Time.current, flag_reason: "x", flagged_by: other)
    post heartbeat_journal_review_project_path(@project), as: :json
    refute response.parsed_body["held"], "a flagged project tells the open page it's gone"
    @status.update!(flagged_at: nil, flag_reason: nil, flagged_by: nil)

    assert_enqueued_with(job: ReportProgressFlagJob) do
      post flag_journal_review_project_path(@project), params: { reason: "Pangram says 95%" }
    end
    assert @status.reload.flagged?
    assert_empty ProgressStatus.queued
    assert_match "Pangram says 95%", @project.reviewer_notes.last.body
    rows = load_deferred(ai_flagged_projects_path, "Review/MarkedProjects/Index", "projects", "pagy")
    assert_equal [ "Pangram says 95%" ], rows["projects"].pluck("flag_reason")
    post unflag_journal_review_project_path(@project)
    assert @status.reload.flagged?, "only admins clear a flag"

    sign_in_as users(:admin)
    post unflag_journal_review_project_path(@project)
    refute @status.reload.flagged?
    assert_equal [ @status ], ProgressStatus.queued.to_a
  end

  test "the feedback goes to the project's thread; notes on particular journals and the decision stay with reviewers" do
    journal = journals(:first)
    review = ProgressReview.decide(@status, reviewer: @reviewer, verdict: "check_back", feedback: "Add photos of the wiring",
      journal_notes: { journal.public_id => "Which sensor did you pick, and why?", journals(:pending_hours).public_id => "  " })
    assert_equal({ journal.public_id => "Which sensor did you pick, and why?" }, review.journal_notes, "blank notes are dropped")
    with_fake_slack do |slack|
      ProgressReviewedJob.perform_now(review, to: "thread")
      call = slack.calls_to(:chat_postMessage).sole
      assert_equal [ @project.slack_channel_id, @project.slack_thread_ts ], [ call[:channel], call[:thread_ts] ]
      assert_match "Add photos of the wiring", call[:text]
      refute_match "Which sensor", call[:text], "notes on journals are for reviewers"
      refute_match "<@", call[:text], "the team is DMed, so the thread doesn't ping them"
    end

    sign_in_as users(:member)
    props = load_deferred(project_path(@project), "Projects/Show", "journal_review")
    refute props["journal_review"]["reviews"].sole.key?("journal_notes"), "the team's page doesn't carry the notes"
    refute props["journal_review"]["reviews"].sole.key?("verdict"), "or whether it was a check back"

    sign_in_as @reviewer
    history = inertia_props(journal_review_project_path(@project), "Review/Progress/Show")["history"]
    assert_equal({ journal.public_id => "Which sensor did you pick, and why?" }, history.sole["journal_notes"])
  end

  test "notes only go on the project's own journals" do
    review = ProgressReview.decide(@status, reviewer: @reviewer, verdict: "check_back", feedback: "Hi", journal_notes: { journals(:web_only).public_id => "Not here" })
    refute review.persisted?
    assert review.errors[:journal_notes].any?
  end

  test "deleting a journal queues a refresh, since its hours no longer count" do
    assert_enqueued_with(job: ProgressRefreshJob, args: [ @project.id ]) { journals(:first).discard }
  end

  test "the team asks for a review from the project page, and it goes to the front of the queue" do
    @status.update!(due_since: nil, due_reason: nil)
    sign_in_as users(:member)
    props = load_deferred(project_path(@project), "Projects/Show", "journal_review")
    assert props["journal_review"]["can_request"]

    post project_review_request_path(@project), params: { note: "Is the wiring clear?" }
    assert_redirected_to project_path(@project)
    assert_equal [ "requested", "Is the wiring clear?" ], [ @status.reload.due_reason, @status.request_note ]

    travel 1.minute do
      post project_review_request_path(@project)
    end
    assert_in_delta Time.current, @status.reload.requested_at, 30, "not again while it's waiting"

    sign_in_as @reviewer
    props = inertia_props(journal_review_project_path(@project), "Review/Progress/Show")
    assert_equal "Is the wiring clear?", props["status"]["request"]["note"]
  end

  test "reviewers are nudged when the queue backs up" do
    with_fake_slack do |slack|
      with_env("SLACK_REVIEWERS_CHANNEL_ID" => "CREVIEW") do
        ProgressQueueNudgeJob.perform_now
        assert_empty slack.calls_to(:chat_postMessage), "nothing has waited long enough yet"

        @status.update!(due_since: 3.days.ago)
        ProgressQueueNudgeJob.perform_now
        call = slack.calls_to(:chat_postMessage).sole
        assert_equal "CREVIEW", call[:channel]
        assert_match "1 project waiting for journal review", call[:text]
      end
    end
  end

  test "the review goes in the thread first, then each person on the team is DMed a link to it" do
    @project.user.update!(slack_id: "UOWNER")
    @reviewer.update!(slack_id: "UREVIEWER")
    review = ProgressReview.decide(@status, reviewer: @reviewer, verdict: "check_back", feedback: "Nice soldering! More photos please.")
    assert_enqueued_with(job: ProgressReviewedJob, args: [ review ])
    clear_enqueued_jobs
    with_fake_slack do |slack|
      ProgressReviewedJob.perform_now(review)
      reply = slack.calls_to(:chat_postMessage).sole
      assert_equal "Journal review: Nice soldering! More photos please.", reply[:text]
      assert review.reload.slack_ts
      assert_enqueued_jobs @project.teammates.uniq.size, only: ProgressReviewedJob

      ProgressReviewedJob.perform_now(review)
      assert_equal 1, slack.calls_to(:chat_postMessage).size, "a rerun doesn't post the reply again"

      ProgressReviewedJob.perform_now(review, to: @project.user)
      dm = slack.calls_to(:chat_postMessage).last
      assert_equal "UOWNER", dm[:channel]
      assert_equal "<@UREVIEWER> reviewed your journals for *#{@project.title}*. <#{review.slack_url}|See the review>", dm[:text]
      assert_match "?thread_ts=#{@project.slack_thread_ts}", review.slack_url
      assert_no_match(/:[a-z_]+:/, reply[:text] + dm[:text], "no emoji")
    end
  end

  test "a reviewer edits their own review's feedback: the page and the thread reply change, with no sign of it" do
    review = ProgressReview.decide(@status, reviewer: @reviewer, verdict: "approved", feedback: "Nice photos")
    review.update_column(:slack_ts, "1700000000.000100")
    other = users(:member)
    other.update!(roles: %w[user reviewer])

    sign_in_as other
    patch journal_review_review_path(review), params: { feedback: "Not mine" }
    assert_equal "Nice photos", review.reload.feedback, "only the reviewer who wrote it, or an admin"

    sign_in_as @reviewer
    props = inertia_props(journal_review_project_path(@project), "Review/Progress/Show")
    assert_equal [ review.public_id ], props["editable_reviews"]
    assert_enqueued_with(job: ProgressReviewEditedJob, args: [ review ]) do
      patch journal_review_review_path(review), params: { feedback: "Great photos of the **wiring**" }
    end
    assert_equal "Great photos of the **wiring**", review.reload.feedback
    patch journal_review_review_path(review), params: { feedback: " " }
    assert_equal "Great photos of the **wiring**", review.reload.feedback, "it can't be emptied"

    with_fake_slack do |slack|
      ProgressReviewEditedJob.perform_now(review)
      update = slack.calls_to(:chat_update).sole
      assert_equal [ @project.slack_channel_id, "1700000000.000100" ], [ update[:channel], update[:ts] ]
      assert_equal "Journal review: Great photos of the *wiring*", update[:text]
    end
  end

  test "admins add a project to the queue by its link; reviewers can't" do
    other = projects(:unlinked)
    sign_in_as @reviewer
    post journal_review_add_path, params: { link: "http://localhost:3000/projects/#{other.public_id}" }
    assert_nil other.reload.progress_status, "only admins add projects"

    sign_in_as users(:admin)
    get journal_review_root_path
    assert inertia_props(journal_review_root_path, "Review/Progress/Index")["can_add"]
    post journal_review_add_path, params: { link: "nope" }
    assert_equal "That isn't a link to a project", flash[:alert]

    post journal_review_add_path, params: { link: "http://localhost:3000/projects/#{other.public_id}" }
    assert_redirected_to journal_review_root_path
    status = other.reload.progress_status
    assert_equal [ "added", users(:admin) ], [ status.due_reason, status.added_by ]
    assert_equal other, ProgressStatus.queued.in_queue_order.first.project, "added ones go to the front"

    post journal_review_add_path, params: { link: other.public_id }
    assert_match "already in the queue", flash[:alert]
  end

  test "a project flagged for AI is posted to the AI flags channel" do
    @status.update!(flagged_at: Time.current, flag_reason: "Every journal reads like a press release", flagged_by: @reviewer)
    with_fake_slack do |slack|
      with_env("SLACK_AI_FLAGS_CHANNEL_ID" => "CFLAGS") { ReportProgressFlagJob.perform_now(@status) }
      call = slack.calls_to(:chat_postMessage).sole
      assert_equal "CFLAGS", call[:channel]
      assert_match "Every journal reads like a press release", call[:text]
      assert_match journal_review_project_path(@project), call[:text]
    end
    with_fake_slack do |slack|
      ReportProgressFlagJob.perform_now(@status)
      assert_empty slack.calls_to(:chat_postMessage), "nothing without the channel set"
    end
  end

  test "a link to a project that's gone goes back to the queue" do
    sign_in_as @reviewer
    get journal_review_project_path("prj_zzzzzz")
    assert_redirected_to journal_review_root_path
    assert_equal "That project isn't in journal review any more.", flash[:alert]
  end
end
