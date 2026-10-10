# frozen_string_literal: true

class UserProfileSerializer < UserSerializer
  attributes :slack_id, :timezone, :verification_status, :created_at
end
