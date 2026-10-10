# frozen_string_literal: true

module Constraints
  class Admin
    def matches?(request)
      user_id = request.session[:user_id]
      return false unless user_id

      User.kept.find_by(id: user_id)&.admin? || false
    end
  end
end
