module ApplicationCable
  # Signed in the same way as a page: the session cookie's user (Authentication). Nobody else gets a connection.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = User.kept.find_by(id: request.session[:user_id]) || reject_unauthorized_connection
    end
  end
end
