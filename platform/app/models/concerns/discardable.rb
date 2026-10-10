# frozen_string_literal: true

# Soft delete. Discarded records stay in the database; use `kept` in queries that should hide them.
module Discardable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(discarded_at: nil) }
    scope :discarded, -> { where.not(discarded_at: nil) }
  end

  def discard = update(discarded_at: Time.current)
  def undiscard = update(discarded_at: nil)
  def discarded? = discarded_at.present?
end
