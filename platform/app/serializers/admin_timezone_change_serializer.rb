# frozen_string_literal: true

# Admin-only. A change to someone's timezone, or one refused, on /admin/users/:id.
class AdminTimezoneChangeSerializer < ApplicationSerializer
  typelize from: :string, to: :string, source: :string, refused: :boolean, created_at: :string

  attributes :from, :to, :source, :refused, :created_at
end
