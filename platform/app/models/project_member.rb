# Someone building a Project with its owner. The owner is projects.user_id and has no row here. Members journal their
# own sessions on the project like the owner does; a journal's hours and XP only ever go to the person who wrote it.
# == Schema Information
#
# Table name: project_members
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_project_members_on_project_id_and_user_id  (project_id,user_id) UNIQUE
#  index_project_members_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class ProjectMember < ApplicationRecord
  has_paper_trail

  belongs_to :project
  belongs_to :user

  validates :user_id, uniqueness: { scope: :project_id }
  validate :not_the_owner
  validate :room_on_the_team, on: :create

  private

  def not_the_owner
    errors.add(:user, "already owns this project") if project && project.user_id == user_id
  end

  # The project row stays locked until this save commits, so two people joining at once can't both take the last place.
  def room_on_the_team
    return if project.nil?

    full = if project.persisted?
      Project.where(id: project.id).lock.pluck(:id)
      1 + ProjectMember.where(project_id: project.id).count >= Project::MAX_TEAM
    else
      project.team_full?
    end
    errors.add(:project, "already has #{Project::MAX_TEAM} people") if full
  end
end
