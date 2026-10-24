# frozen_string_literal: true

# Admin-only. A token on /admin/mcp. Never the token itself, which only exists in the response that minted it.
class AdminMcpTokenSerializer < ApplicationSerializer
  typelize_from AdminToken
  typelize live: :boolean

  attributes :id, :name, :token_hint, :created_at, :last_used_at, :expires_at, :revoked_at
  attribute(:live, &:live?)
  one :user, key: :owner, resource: PersonSerializer
end
