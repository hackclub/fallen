# frozen_string_literal: true

# /admin/teams: the weekly team race. Admins pay a week's win once it is over, and only once.
class Admin::TeamRacePolicy < ApplicationPolicy
  def show? = admin?
  def pay? = admin? && record.payable?
end
