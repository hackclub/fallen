# frozen_string_literal: true

module Constraints
  class JournalReviewer
    def matches?(request)
      user_id = request.session[:user_id]
      return false unless user_id

      User.kept.find_by(id: user_id)&.reviews_journals? || false
    end
  end
end
