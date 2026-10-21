# frozen_string_literal: true

# What a project's team panel and the invite cards on Home and Projects show.
module TeamProps
  extend ActiveSupport::Concern

  PEOPLE_RESULTS = 6

  private

  # Everyone on the team with what they have logged here. Invites still waiting and the join link are only for the
  # team, who can share them.
  def team_props(project, invite:)
    totals = project.totals_by_author
    people = project.teammates.map do |person|
      PersonSerializer.render(person).merge(owner: person.id == project.user_id, **totals.fetch(person.id, { minutes: 0, journals: 0 }))
    end
    team = { people: people, max: Project::MAX_TEAM }
    return team unless invite

    invites = project.invites.includes(:user).order(:created_at).to_a
    team.merge(
      invites: invites.map { |pending| { id: pending.public_id, invitee: PersonSerializer.render(pending.user) } },
      join_url: join_url(project.join_token!), open_seats: project.open_seats(invites.size)
    )
  end

  def pending_invites
    invites = current_user.project_invites.live.order(created_at: :desc)
      .includes(:user, :inviter, project: [ :user, { memberships: :user, banner_attachment: :blob } ])
    ProjectInviteSerializer.render(invites)
  end

  # Fallen people (past the onboarding, signed in with Hack Club Auth) by name, minus anyone on the team or invited.
  def people_to_invite(project, query)
    return [] if query.to_s.strip.length < 2

    taken = project.teammates.map(&:id) + project.invites.pluck(:user_id)
    PersonSerializer.render(User.on_a_team.where.not(id: taken).search_by_name(query.to_s.strip.first(60)).limit(PEOPLE_RESULTS))
  end
end
