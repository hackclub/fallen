# Receives everything Slack sends us. Requests are verified with the signing secret, then handed to
# SlackBot (lib/slack_bot), which routes them to handlers in app/bot by naming convention.
class SlackController < ActionController::API
  before_action :verify_slack_signature!

  # Events API. Always acks immediately; the work happens in SlackEventJob.
  def events
    body = JSON.parse(request.raw_post)

    return render json: { challenge: body["challenge"] } if body["type"] == "url_verification"
    return head :ok if request.headers["X-Slack-Retry-Num"].present?

    SlackEventJob.perform_later(body)
    head :ok
  end

  # Slash commands (application/x-www-form-urlencoded). The handler's first `respond` is the ack body.
  def commands
    payload = params.to_unsafe_h.except("controller", "action")
    render_slack_response SlackBot.handle(:command, payload)
  end

  # Block actions, view submissions, shortcuts (form field `payload` holding JSON).
  def interactions
    payload = JSON.parse(params.require(:payload))
    render_slack_response SlackBot.handle(:interaction, payload)
  end

  private

  def render_slack_response(response)
    response.present? ? render(json: response) : head(:ok)
  end

  def verify_slack_signature!
    Slack::Events::Request.new(request).verify!
  rescue Slack::Events::Request::MissingSigningSecret
    Rails.logger.error("SLACK_SIGNING_SECRET is not set; rejecting Slack request")
    head :service_unavailable
  rescue Slack::Events::Request::TimestampExpired, Slack::Events::Request::InvalidSignature
    head :unauthorized
  end
end
