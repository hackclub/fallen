# frozen_string_literal: true

# Soft delete. Discarded records stay in the database; use `kept` in queries that should hide them.
#
# `destroy` discards too, so a stray call from the console, a controller or a `dependent: :destroy` cannot lose
# data or purge uploads. Only PrivacyRequest erases for real, with `delete_all`.
module Discardable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(discarded_at: nil) }
    scope :discarded, -> { where.not(discarded_at: nil) }
  end

  def discard = update(discarded_at: Time.current)
  def undiscard = update(discarded_at: nil)
  def discarded? = discarded_at.present?

  def destroy = discard && self
  def destroy! = destroy || raise(ActiveRecord::RecordNotDestroyed.new("Failed to discard the record", self))
end
