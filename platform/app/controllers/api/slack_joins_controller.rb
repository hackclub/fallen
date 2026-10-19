# The Slack "join" button's webhook: a soft signup that makes a trial account for a Slack ID before they visit the site,
# so they are in Airtable right away (SlackJoinJob, User.join_from_slack!). Signing in with Hack Club Auth later claims
# it (User.from_hca_code!). The secret is SLACK_JOIN_SECRET, sent as `Authorization: Bearer <secret>`, an
# `X-Fallen-Secret` header or `?secret=` for senders that can't set headers. The Slack ID is `slack_id` (or `slackId`,
# `user_id`, `user.id`) in a JSON or form body or the query string, next to any UTM tags and `ref` (SignupSource::PARAMS)
# to keep on the account.
module Api
  class SlackJoinsController < ActionController::API
    def create
      return render json: { ok: false, error: "unauthorized" }, status: :unauthorized unless authorized?

      slack_id = given_slack_id
      return render json: { ok: false, error: "missing or malformed slack_id" }, status: :bad_request unless slack_id.match?(User::SLACK_ID)

      if (user = User.kept.find_by(slack_id: slack_id))
        render json: { ok: true, created: false, user_id: user.public_id, signed_in: !user.trial? }
      else
        SlackJoinJob.perform_later(slack_id, given_signup_source)
        render json: { ok: true, queued: true }, status: :accepted
      end
    end

    private

    def authorized?
      secret = ENV["SLACK_JOIN_SECRET"].to_s
      given = request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1] || request.headers["X-Fallen-Secret"] || params[:secret]
      secret.present? && ActiveSupport::SecurityUtils.secure_compare(given.to_s, secret)
    end

    def given_slack_id
      [ fields[:slack_id], fields[:slackId], fields[:user_id], fields.dig(:user, :id) ].find { it.is_a?(String) }.to_s.strip.upcase
    end

    def given_signup_source
      SignupSource::PARAMS.index_with { fields[it] }.select { |_, value| value.is_a?(String) && value.present? }
        .transform_values { it.truncate(SignupSource::MAX_LENGTH) }
    end

    def fields = @fields ||= params.to_unsafe_h.merge(json_sent_as_text)

    # Webhook senders are sloppy about content-type, so a JSON body counts whatever it is labelled.
    def json_sent_as_text
      body = request.raw_post.to_s
      return {} if request.content_mime_type&.json? || !body.lstrip.start_with?("{")

      JSON.parse(body)
    rescue JSON::ParserError
      {}
    end
  end
end
