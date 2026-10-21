# frozen_string_literal: true

# Someone as other people see them: teammates on a project, a journal's author, whoever sent an invite.
class PersonSerializer < ApplicationSerializer
  typelize_from User
  typelize id: :string, name: :string, avatar: :string
  attribute(:id) { |user| user.public_id }
  attribute(:name, &:display_name)
  attribute(:avatar, &:avatar_url)
end
