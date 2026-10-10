# frozen_string_literal: true

module InertiaHelpers
  extend ActiveSupport::Concern

  private

  def pagy_props(pagy)
    {
      count: pagy.count,
      page: pagy.page,
      limit: pagy.limit,
      pages: pagy.last,
      next: pagy.next,
      prev: pagy.previous
    }
  end

  # Redirect back with validation errors the way Inertia expects.
  def inertia_errors(record, fallback_location:)
    redirect_back fallback_location: fallback_location, inertia: { errors: record.errors.to_hash }
  end
end
