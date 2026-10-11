# Endpoints the Hack Club privacy hub calls (https://yeet.hackclub.com/docs/deletions). The hub sends a signed
# token and no body; the person is found from the token's claims and nothing else. Logs carry only the
# request id and outcome, never the token or anything that identifies the person.
module Api
  class PrivacyController < ActionController::API
    rescue_from PrivacyToken::Invalid, with: -> { render_error(:unauthorized, "invalid_token") }
    rescue_from PrivacyToken::ActionMismatch, with: -> { render_error(:bad_request, "action_mismatch") }
    rescue_from PrivacyToken::KeysUnavailable, with: -> { render_error(:service_unavailable, "jwks_unavailable") }

    def delete
      claims = verified_claims("delete")
      return render_error(:conflict, "replayed", claims) unless PrivacyTokenUse.record(claims["jti"])

      respond_with claims, PrivacyRequest.new(claims["subject"]).run(commit: claims["dry_run"] == false)
    end

    # Never changes anything: runs the same deletion as a dry run and reports what it would remove.
    def export
      claims = verified_claims("export")
      return render_error(:conflict, "replayed", claims) unless PrivacyTokenUse.record(claims["jti"])

      respond_with claims, PrivacyRequest.new(claims["subject"]).run(commit: false)
    end

    private

    def verified_claims(action)
      token = request.authorization.to_s[/\ABearer (.+)\z/, 1]
      PrivacyToken.verify!(token, action: action)
    end

    def respond_with(claims, result)
      log claims, result[:found] ? "found" : "not_found"
      render json: {
        request_id: claims["request_id"],
        found: result[:found],
        dry_run: claims["dry_run"],
        deleted: result[:deleted],
        retained: result[:retained]
      }
    end

    def render_error(status, code, claims = nil)
      log claims, code
      render json: { error: code }, status: status
    end

    def log(claims, outcome)
      Rails.logger.info("privacy hub #{action_name}: request_id=#{claims&.dig('request_id') || 'unverified'} dry_run=#{claims&.dig('dry_run').inspect} outcome=#{outcome}")
    end
  end
end
