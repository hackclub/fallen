# The landing page's "Get started as": the browser asks Hack Club Auth's whoami who is signed in there, then sends
# the email here for their Slack picture. Answers 202 while SlackAvatarJob looks it up, and the page asks again.
class SlackAvatarsController < ApplicationController
  allow_unauthenticated_access only: :create # Asked before anyone has signed in to Fallen
  skip_forgery_protection only: :create # Changes nothing for the session
  skip_after_action :verify_authorized # Slack profile pictures are public to the workspace
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  rate_limit to: 30, within: 1.minute, only: :create, with: -> { head :too_many_requests }

  def create
    email = params[:email].to_s.strip.downcase
    return head :unprocessable_content unless email.match?(URI::MailTo::EMAIL_REGEXP)

    avatar = SlackAvatars.fetch(email)
    return head :accepted if avatar == :pending

    render json: { url: avatar }
  end
end
