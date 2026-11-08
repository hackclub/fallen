# frozen_string_literal: true

module Constraints
  class DesignReviewer
    def matches?(request)
      user_id = request.session[:user_id]
      return false unless user_id

      User.kept.find_by(id: user_id)&.reviews_designs? || false
    end
  end
end
