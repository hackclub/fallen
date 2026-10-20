# frozen_string_literal: true

# /admin/flags: Flipper feature flags. Admins see and change every flag.
class Admin::FlagPolicy < ApplicationPolicy
  def index? = admin?
  def show? = admin?
  def create? = admin?
  def update? = admin?
  def destroy? = admin?
end
