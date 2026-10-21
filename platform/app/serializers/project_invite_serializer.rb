# frozen_string_literal: true

# An invite as the person asked sees it (home page, the invite's own page) and as the team sees it waiting. Callers
# preload `user`, `inviter` and `project: [:user, { memberships: :user, banner_attachment: :blob }]`.
# == Schema Information
#
# Table name: project_invites
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  inviter_id :bigint           not null
#  project_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_project_invites_on_inviter_id              (inviter_id)
#  index_project_invites_on_project_id_and_user_id  (project_id,user_id) UNIQUE
#  index_project_invites_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (inviter_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class ProjectInviteSerializer < ApplicationSerializer
  typelize_from ProjectInvite
  typelize id: :string, project: "{ id: string; title: string; description: string | null; banner_url: string | null; teammates: Array<{ id: string; name: string; avatar: string }> }"
  attributes :created_at
  attribute(:id) { |invite| invite.public_id }
  one :user, key: :invitee, resource: PersonSerializer
  one :inviter, resource: PersonSerializer
  attribute(:project) do |invite|
    project = invite.project
    blob = project.banner.attachment&.blob
    {
      id: project.public_id, title: project.title, description: project.description,
      banner_url: blob && Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true),
      teammates: PersonSerializer.render(project.teammates)
    }
  end
end
