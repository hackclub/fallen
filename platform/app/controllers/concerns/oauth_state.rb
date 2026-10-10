# frozen_string_literal: true

# OAuth `state` lives in a short-lived encrypted cookie instead of the session: it survives reset_session
# and the cross-site redirect back from the provider, which strict browser privacy settings can otherwise break.
# Several states are kept so two sign-in tabs don't invalidate each other.
module OauthState
  extend ActiveSupport::Concern

  COOKIE = :oauth_state
  MAX_STATES = 4

  private

  def issue_oauth_state
    state = SecureRandom.hex(24)
    states = (Array(cookies.encrypted[COOKIE]) + [ state ]).last(MAX_STATES)
    cookies.encrypted[COOKIE] = oauth_cookie_options.merge(value: states)
    state
  end

  # Consumes every stored state; returns true if `state` was one of them.
  def consume_oauth_state(state)
    states = Array(cookies.encrypted[COOKIE])
    cookies.delete(COOKIE, **oauth_cookie_options.except(:expires, :httponly))
    state.present? && states.any? { |s| ActiveSupport::SecurityUtils.secure_compare(s, state) }
  end

  def oauth_cookie_options
    { expires: 10.minutes, httponly: true, secure: Rails.env.production?, same_site: :lax }
  end
end
