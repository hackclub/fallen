# frozen_string_literal: true

# Remembers where a signed-out visitor first came from (UTM tags, `?ref=`, the referring site, the page they landed
# on) in an encrypted cookie, so the account created at sign-in can keep it (User#signup_source). First visit wins.
# A cookie rather than the session because sign-in resets the session.
module SignupSource
  extend ActiveSupport::Concern

  COOKIE = :signup_source
  PARAMS = %w[utm_source utm_medium utm_campaign utm_term utm_content ref].freeze
  MAX_LENGTH = 200

  # Prepended so a tagged link to a page that needs sign-in is still counted before the redirect home.
  included do
    prepend_before_action :remember_signup_source
  end

  private

  def remember_signup_source
    return if session[:user_id].present? || !request.get? || request.headers["X-Inertia"] || cookies[COOKIE].present?

    source = PARAMS.index_with { |key| params[key] }.select { |_, value| value.is_a?(String) && value.present? }
    source["referrer"] = external_referrer if external_referrer
    return if source.empty?

    source["landing_path"] = request.path
    source = source.transform_values { |value| value.truncate(MAX_LENGTH) }
    cookies.encrypted[COOKIE] = { value: source.merge("at" => Time.current.iso8601), expires: 30.days, httponly: true, secure: Rails.env.production?, same_site: :lax }
  end

  # Clears the cookie either way, so it never sticks to a browser after someone signs in.
  def take_signup_source
    source = cookies.encrypted[COOKIE]
    cookies.delete(COOKIE)
    source.is_a?(Hash) ? source : {}
  end

  # Scheme, host and path only: query strings on other sites can carry things that aren't ours to keep.
  def external_referrer
    return @external_referrer if defined?(@external_referrer)

    uri = URI.parse(request.referer.to_s)
    @external_referrer = if uri.is_a?(URI::HTTP) && uri.host.present? && uri.host != request.host
      "#{uri.scheme}://#{uri.host}#{uri.path}".truncate(MAX_LENGTH)
    end
  rescue URI::InvalidURIError
    @external_referrer = nil
  end
end
