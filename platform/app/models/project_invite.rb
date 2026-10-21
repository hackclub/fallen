# A teammate asked to join a Project by name (ProjectInvitesController). They hear about it in a Slack DM
# (ProjectInviteJob) and on their home page, and joining or declining removes it. Anyone can also join with the
# project's link (Project#join_token) without one.
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
class ProjectInvite < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :pin
  has_paper_trail

  belongs_to :project
  belongs_to :user
  belongs_to :inviter, class_name: "User"

  validates :user_id, uniqueness: { scope: :project_id, message: "is already invited" }
  validate :not_on_the_team
  validate :room_on_the_team, on: :create

  scope :live, -> { joins(:project).merge(Project.kept) }

  # Joins the team and drops the invite, or returns the membership holding why not.
  def accept!
    member = project.memberships.build(user: user)
    transaction { destroy! if member.save }
    member
  end

  private

  def not_on_the_team
    errors.add(:user, "is already on the team") if project&.on_team?(user)
  end

  def room_on_the_team
    errors.add(:project, "already has #{Project::MAX_TEAM} people") if project&.team_full?
  end
end
