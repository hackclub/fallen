# frozen_string_literal: true

# /admin/stats: activity, tracked time and the signup funnel. Admins only.
class Admin::StatsPolicy < ApplicationPolicy
  def show? = admin?
end
