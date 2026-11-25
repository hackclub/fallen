# frozen_string_literal: true

# /admin/review-leaderboard: who has reviewed how much. Admins only.
class Admin::ReviewLeaderboardPolicy < ApplicationPolicy
  def show? = admin?
end
