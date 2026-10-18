require "test_helper"

class ProjectsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:member) }

  test "lists only my projects" do
    get projects_path
    assert_response :success
    assert_includes response.body, projects(:station).public_id
    assert_not_includes response.body, projects(:admins).public_id
  end

  test "shows a project with its journals and hides other people's" do
    get project_path(projects(:station))
    assert_response :success
    assert_includes response.body, journals(:first).public_id
    assert_includes response.body, projects(:station).slack_url

    get project_path(projects(:admins))
    assert_redirected_to root_path
  end

  test "journals are paginated newest first" do
    pad_journals(projects(:station), ProjectsController::JOURNALS_PER_PAGE)
    props = inertia_props(project_path(projects(:station)), "Projects/Show")
    assert_equal ProjectsController::JOURNALS_PER_PAGE, props["journals"].size
    assert_equal 2, props["pagy"]["pages"]

    props = inertia_props(project_path(projects(:station), page: 2), "Projects/Show")
    assert_equal [ journals(:pending_hours), journals(:first) ].map(&:public_id).sort, props["journals"].pluck("id").sort
  end

  test "creating a project posts its anchor to slack" do
    assert_enqueued_with(job: PostProjectToSlackJob) do
      post projects_path, params: { project: { title: "Robot arm", description: "", repo_url: "", demo_url: "" } }
    end
    project = Project.last
    assert_redirected_to project_path(project)
    assert_equal users(:member), project.user
  end

  test "a project banner is a direct upload that can be swapped or removed" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("png"), filename: "banner.png", content_type: "image/png")
    post projects_path, params: { project: { title: "Robot arm", banner: blob.signed_id } }
    project = Project.last
    assert_equal blob, project.banner.blob
    assert_equal blob.signed_id, inertia_props(project_path(project), "Projects/Show")["project"]["banner"]["id"]

    patch project_path(project), params: { project: { title: "Robot arm", banner: blob.signed_id } }
    assert_equal blob, project.reload.banner.blob

    patch project_path(project), params: { project: { title: "Robot arm", banner: "" } }
    assert_not project.reload.banner.attached?
  end

  test "renaming a project rewrites its slack message, other edits do not" do
    project = projects(:station)
    assert_enqueued_with(job: UpdateProjectOnSlackJob, args: [ project ]) do
      patch project_path(project), params: { project: { title: "Robot arm" } }
    end
    assert_no_enqueued_jobs(only: UpdateProjectOnSlackJob) do
      patch project_path(project), params: { project: { repo_url: "https://github.com/x/y" } }
    end
  end

  test "a project without a banner shows its first journal photo" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("png"), filename: "board.png", content_type: "image/png")
    journals(:first).images.attach(blob)

    cards = inertia_props(projects_path, "Projects/Index")["projects"].index_by { |p| p["id"] }
    assert_includes cards[projects(:station).public_id]["cover_url"], blob.filename.to_s
    assert_nil cards[projects(:station).public_id]["banner"]
    assert_nil cards[projects(:unlinked).public_id]["cover_url"]
  end

  test "rejects a banner that is not an image" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF"), filename: "plan.pdf", content_type: "application/pdf")
    assert_no_difference -> { Project.count } do
      post projects_path, params: { project: { title: "Robot arm", banner: blob.signed_id } }
    end
  end

  test "rejects a project without a title" do
    post projects_path, params: { project: { title: "" } }, headers: { "X-Inertia" => "true", "X-Inertia-Version" => "" }
    assert_response :found
    assert_equal 0, Project.where(title: "").count
  end

  test "writing a journal syncs to slack and earns xp" do
    assert_enqueued_with(job: SyncJournalToSlackJob) do
      post project_journals_path(projects(:station)), params: { journal: { body: journal_text("Wired the display"), duration: "1h", images: [ photo.signed_id ] } }
    end
    journal = Journal.last
    assert_redirected_to project_path(projects(:station))
    assert_equal "web", journal.source
    assert_equal 8, journal.xp
    assert_equal 28, users(:member).reload.xp
  end

  test "journals carry images, one photo per two hours" do
    blob = photo("board.png")
    assert_no_difference -> { Journal.count } do
      post project_journals_path(projects(:station)), params: { journal: { body: journal_text("no photo"), duration: "0.75" } }
    end
    post project_journals_path(projects(:station)), params: { journal: { body: journal_text("![board](x)"), duration: "0.75", images: [ blob.signed_id ] } }
    journal = Journal.last
    assert_equal 1, journal.images.count

    get project_path(projects(:station))
    assert_includes response.body, "board.png"

    patch journal_path(journal), params: { journal: { body: journal_text("no photo"), images: [] } }
    assert_equal 1, journal.reload.images.count, "a journal keeps the photos its hours need"
    patch journal_path(journal), params: { journal: { body: journal_text("longer"), duration: "3h", images: [ blob.signed_id ] } }
    assert_equal 45, journal.reload.duration_minutes, "three hours need two photos"
  end

  test "a journal can take its hours from picked Lapse timelapses, and drop them to type them" do
    timelapse = lapse_timelapses(:desk)
    post project_journals_path(projects(:station)), params: { journal: { body: journal_text("Soldered"), duration: "", lapse_timelapses: [ timelapse.public_id ], images: [ photo.signed_id ] } }
    journal = Journal.last
    assert_equal [ timelapse ], journal.lapse_timelapses
    assert_equal 90, journal.duration_minutes

    get project_path(projects(:station))
    assert_includes response.body, timelapse.url

    patch journal_path(journal), params: { journal: { body: journal_text("Soldered"), duration: "0.5", images: journal.images.map(&:signed_id) } }
    assert_empty journal.reload.lapse_timelapses
    assert_equal 30, journal.duration_minutes
  end

  test "someone else's timelapse cannot be picked" do
    assert_no_difference -> { Journal.count } do
      post project_journals_path(projects(:station)), params: { journal: { body: journal_text("x"), lapse_timelapses: [ lapse_timelapses(:desk).public_id, lapse_timelapses(:admins).public_id ], images: [ photo.signed_id ] } }
    end
    assert_response :not_found
  end

  test "the composer lists all the owner's timelapses, saying which journal has one" do
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text("x"), duration: "1", images: [ photo ])
    lapse_timelapses(:hidden).update!(journal: journal)
    props = load_deferred(project_path(projects(:station)), "Projects/Show", "lapse")
    assert_equal [ lapse_timelapses(:desk).public_id, lapse_timelapses(:hidden).public_id ], props["lapse"]["timelapses"].pluck("id")
    assert_nil props["lapse"]["timelapses"].last["unusable_reason"]
    assert_match(/\Aon your journal from /, props["lapse"]["timelapses"].last["claim_text"])
    assert_equal "/projects/#{projects(:station).to_param}#journal-#{journal.public_id}", props["lapse"]["timelapses"].last["claim_url"]
    assert_nil props["lapse"]["timelapses"].first["claim_text"]
  end

  test "journals wait for slack, projects do not" do
    users(:member).disconnect_slack!
    get project_path(projects(:station))
    assert_response :success
    assert_includes response.body, '"journal":false'

    post project_journals_path(projects(:station)), params: { journal: { body: journal_text("hi") } }
    assert_redirected_to root_path
    post projects_path, params: { project: { title: "Made while onboarding" } }
    assert Project.exists?(title: "Made while onboarding")
  end

  test "cannot journal on someone else's project" do
    post project_journals_path(projects(:admins)), params: { journal: { body: journal_text("hi") } }
    assert_redirected_to root_path
  end

  test "updating and deleting journals syncs to slack" do
    patch journal_path(journals(:first)), params: { journal: { body: journal_text("Edited") } }
    assert_redirected_to project_path(projects(:station))
    assert_equal journal_text("Edited"), journals(:first).reload.body

    assert_enqueued_with(job: SyncJournalToSlackJob, args: [ journals(:first), "delete" ]) do
      delete journal_path(journals(:first))
    end
    assert journals(:first).reload.discarded?
  end

  test "deleting a project soft deletes it" do
    delete project_path(projects(:station))
    assert_redirected_to projects_path
    assert projects(:station).reload.discarded?
  end

  test "disconnecting slack clears the user token" do
    with_fake_slack do
      delete disconnect_slack_path
    end
    assert_redirected_to projects_path
    assert_not users(:member).reload.slack_connected?
  end
end
