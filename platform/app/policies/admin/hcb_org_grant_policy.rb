# frozen_string_literal: true

# /admin/grants (On HCB): admins see every card grant in the HCB org and say which ones aren't design funding.
class Admin::HcbOrgGrantPolicy < ApplicationPolicy
  def update? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.all : scope.none
  end
end
