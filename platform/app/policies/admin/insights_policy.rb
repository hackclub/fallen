# frozen_string_literal: true

# /admin/insights: request and job timings. Admins only.
class Admin::InsightsPolicy < ApplicationPolicy
  def show? = admin?
end
