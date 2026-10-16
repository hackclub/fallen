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

  test "writing a journal syncs to slack" do
    assert_enqueued_with(job: SyncJournalToSlackJob) do
      post project_journals_path(projects(:station)), params: { journal: { body: "Wired the display", duration: "1h" } }
    end
    journal = Journal.last
    assert_redirected_to project_path(projects(:station))
    assert_equal "web", journal.source
  end

  test "journals carry images and a lapse link" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("png"), filename: "board.png", content_type: "image/png")
    post project_journals_path(projects(:station)), params: { journal: { body: "![board](x)", duration: "45m", lapse_url: "https://lapse.hackclub.com/t/1", images: [ blob.signed_id ] } }
    journal = Journal.last
    assert_equal 1, journal.images.count
    assert_equal "https://lapse.hackclub.com/t/1", journal.lapse_url

    get project_path(projects(:station))
    assert_includes response.body, "board.png"

    patch journal_path(journal), params: { journal: { body: "no photo", lapse_url: "", images: [] } }
    assert_equal 0, journal.reload.images.count
  end

  test "journals wait for slack, projects do not" do
    users(:member).disconnect_slack!
    get project_path(projects(:station))
    assert_response :success
    assert_includes response.body, '"journal":false'

    post project_journals_path(projects(:station)), params: { journal: { body: "hi" } }
    assert_redirected_to root_path
    post projects_path, params: { project: { title: "Made while onboarding" } }
    assert Project.exists?(title: "Made while onboarding")
  end

  test "cannot journal on someone else's project" do
    post project_journals_path(projects(:admins)), params: { journal: { body: "hi" } }
    assert_redirected_to root_path
  end

  test "updating and deleting journals syncs to slack" do
    patch journal_path(journals(:first)), params: { journal: { body: "Edited" } }
    assert_redirected_to project_path(projects(:station))
    assert_equal "Edited", journals(:first).reload.body

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
