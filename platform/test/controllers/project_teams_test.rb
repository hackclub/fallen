require "test_helper"

class ProjectTeamsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @project = projects(:station)
    @owner = users(:member)
    @friend = User.create!(hca_id: "hca_friend", email: "friend@example.com", display_name: "Friendly Builder", roles: [ "user" ], pet: "sami", slack_id: "U0FRIEND")
  end

  test "the join link shows the project to anyone and joins whoever signs in" do
    token = @project.join_token!
    get join_path(token)
    assert_response :success

    get dev_sign_in_as_path(@friend.id)
    assert_redirected_to join_path(token), "back to the link after signing in"
    props = inertia_props(join_path(token), "ProjectJoins/Show")
    assert_equal [ @owner.public_id ], props["project"]["teammates"].pluck("id")
    assert props["signed_in"]

    assert_enqueued_with(job: TeammateJoinedJob, args: [ @project, @friend ]) { post join_path(token) }
    assert_redirected_to project_path(@project)
    assert @project.reload.on_team?(@friend)
    assert JournalPolicy.new(@friend.tap(&:skip_slack!), @project.journals.build(user: @friend)).create?

    get join_path(token)
    assert_redirected_to project_path(@project), "already on it"
    assert_includes inertia_props(projects_path, "Projects/Index")["projects"].pluck("id"), @project.public_id
  end

  test "a new link stops the old one working" do
    old = @project.join_token!
    sign_in_as @owner
    post project_join_link_path(@project)
    assert_not_equal old, @project.reload.join_token

    sign_in_as @friend
    get join_path(old)
    assert_response :not_found
  end

  test "inviting by name sends a DM and waits on their home page until they answer" do
    sign_in_as @owner
    props = inertia_props(project_path(@project), "Projects/Show")
    assert_nil props["people"], "only sent while searching"
    assert_equal @project.reload.join_token, props["team"]["join_url"].split("/").last

    get project_path(@project, people_query: "Friend"), headers: { "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version.to_s,
                                                                   "X-Inertia-Partial-Component" => "Projects/Show", "X-Inertia-Partial-Data" => "people" }
    assert_equal [ @friend.public_id ], response.parsed_body["props"]["people"].pluck("id")
    assert_not response.parsed_body["props"]["people"].first.key?("email")

    assert_enqueued_with(job: ProjectInviteJob) { post project_invites_path(@project), params: { invite: { user_id: @friend.public_id } } }
    invite = ProjectInvite.last
    assert_equal [ @friend.public_id ], inertia_props(project_path(@project), "Projects/Show")["team"]["invites"].map { it["invitee"]["id"] }

    sign_in_as @friend
    assert_equal [ invite.public_id ], inertia_props(home_path, "Home/Index")["invites"].pluck("id")
    assert_equal invite.public_id, inertia_props(invite_path(invite), "ProjectInvites/Show")["invite"]["id"]

    post accept_invite_path(invite)
    assert_redirected_to project_path(@project)
    assert @project.reload.on_team?(@friend)
    assert_not ProjectInvite.exists?(invite.id)
  end

  test "declining or cancelling an invite removes it, and only they or the team can" do
    invite = @project.invites.create!(user: @friend, inviter: @owner)
    stranger = users(:admin)
    sign_in_as stranger
    delete invite_path(invite)
    assert ProjectInvite.exists?(invite.id)
    get invite_path(invite)
    assert_redirected_to root_path

    sign_in_as @friend
    delete invite_path(invite)
    assert_not ProjectInvite.exists?(invite.id)
  end

  test "the invite DM links to the invite" do
    invite = @project.invites.create!(user: @friend, inviter: @owner)
    with_fake_slack do |slack|
      ProjectInviteJob.perform_now(invite)
      dm = slack.calls_to(:chat_postMessage).last
      assert_equal "U0FRIEND", dm[:channel]
      assert_includes dm[:text], @project.title
      assert_includes dm.to_s, "/invites/#{invite.public_id}"
    end
  end

  test "a team holds MAX_TEAM people, counting invites still waiting" do
    others = (2..Project::MAX_TEAM).map { |i| User.create!(email: "t#{i}@example.com", display_name: "Teammate #{i}", hca_id: "hca_t#{i}", roles: [ "user" ], pet: "lulu") }
    others.first(Project::MAX_TEAM - 2).each { |user| @project.memberships.create!(user: user) }
    last = @project.reload.memberships.build(user: @friend)
    assert last.valid?, "the last spot can be taken"
    @project.memberships.reset
    @project.invites.create!(user: others.last, inviter: @owner)
    assert_equal 0, @project.reload.open_seats

    sign_in_as @owner
    assert_no_difference -> { ProjectInvite.count } do
      post project_invites_path(@project), params: { invite: { user_id: @friend.public_id } }
    end

    @project.memberships.create!(user: others.last)
    token = @project.reload.join_token!
    assert_not ProjectMember.new(project: @project, user: @friend).valid?
    sign_in_as @friend
    assert inertia_props(join_path(token), "ProjectJoins/Show")["full"]
  end

  test "teammates edit the project and journal on it, but only the owner takes people off or deletes it" do
    @project.memberships.create!(user: @friend)
    sign_in_as @friend
    patch project_path(@project), params: { project: { description: "Now with wind speed" } }
    assert_equal "Now with wind speed", @project.reload.description

    other = User.create!(email: "o@example.com", display_name: "Other", hca_id: "hca_o", roles: [ "user" ], pet: "lulu")
    @project.memberships.create!(user: other)
    delete project_teammate_path(@project, other.public_id)
    assert @project.reload.on_team?(other)

    sign_in_as @owner
    delete project_path(@project)
    assert @project.reload.kept?, "not while others are on it"
    delete project_teammate_path(@project, other.public_id)
    assert_not @project.reload.on_team?(other)
  end

  test "someone who leaves keeps their journals and can still find them" do
    @project.memberships.create!(user: @friend)
    journal = @project.journals.create!(user: @friend, body: journal_text, duration: "1", images: [ photo ], source: "web")
    sign_in_as @friend

    delete project_teammate_path(@project, @friend.public_id)
    assert_redirected_to projects_path
    assert_not @project.reload.on_team?(@friend)
    assert journal.reload.kept?
    assert_equal 1, journal.xp_entry.amount.positive? ? 1 : 0

    card = inertia_props(projects_path, "Projects/Index")["projects"].find { it["id"] == @project.public_id }
    assert_equal "former", card["role"]
    props = inertia_props(project_path(@project), "Projects/Show")
    assert_not props["can"]["journal"]
    assert_equal [ @friend.public_id ], props["journals"].select { it["id"] == journal.public_id }.map { it["author"]["id"] }
    patch journal_path(journal), params: { journal: { body: journal_text("Edited after leaving"), duration: "1", images: journal.images.map(&:signed_id) } }
    assert_includes journal.reload.body, "Edited after leaving"
  end

  test "the owner leaving hands the project to whoever joined first" do
    @project.memberships.create!(user: @friend)
    sign_in_as @owner
    delete project_teammate_path(@project, @owner.public_id)
    assert_equal @friend, @project.reload.user
    assert_empty @project.memberships

    sign_in_as @friend
    delete project_teammate_path(@project, @friend.public_id)
    assert_equal @friend, @project.reload.user, "nobody to hand it to"
  end

  test "a journal's hours and XP go only to whoever wrote it" do
    @project.memberships.create!(user: @friend)
    assert_no_difference -> { @owner.reload.xp } do
      @project.journals.create!(user: @friend, body: journal_text, duration: "2", images: [ photo ], source: "web")
    end
    assert @friend.reload.xp.positive?
  end

  test "a teammate's approved project counts for them" do
    @project.memberships.create!(user: @friend)
    @project.update!(approved: true)
    assert Project.kept.approved.involving(@friend).exists?
  end
end
