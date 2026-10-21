# frozen_string_literal: true

class WritingCheckPolicy < ApplicationPolicy
  def create? = user.slack_ready? && WritingCheck.enabled_for?(user)
  def show? = owner?
end
