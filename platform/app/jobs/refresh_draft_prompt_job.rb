# Redraws a journal draft's Slack prompt in place once something it was waiting on happened elsewhere: Lapse
# connected on Fallen (LapseAuthController), or "Check again" after recording a timelapse. Takes a fresh copy of
# their timelapses first, so the picker lists them. `duration` is what was in the time box, kept as typed.
class RefreshDraftPromptJob < ApplicationJob
  queue_as :realtime
  # Saved or dropped since; there is no prompt to redraw.
  discard_on ActiveJob::DeserializationError

  def perform(draft, duration = nil)
    return unless draft.prompt_live?

    LapseTimelapse.sync_if_connected(draft.user)
    prompt = SlackMessages.draft_prompt(draft, duration: duration, tracked: TrackedTime.new(draft.user).seconds / 60)
    Faraday.post(draft.prompt_url, { replace_original: true, response_type: "ephemeral", **prompt }.to_json, "Content-Type" => "application/json")
  rescue Faraday::Error => e
    Rails.logger.warn({ event: "refresh_draft_prompt.failed", draft_id: draft.id, error: e.message }.to_json)
  end
end
