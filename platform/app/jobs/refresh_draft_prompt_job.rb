# Redraws a journal draft's Slack prompt once something it was waiting on happened elsewhere: Lapse connected on
# Fallen (LapseAuthController), "Check again" after recording a timelapse, or the timelapse picker closed with
# "Done". Takes a fresh copy of their timelapses first. `duration` is what was in the time box, kept as typed.
#
# Replacing an ephemeral message later through a response_url can lose its thread and show it in the channel, so
# the old prompt is deleted through it and the new one posted into the project's thread the way JournalPromptJob
# does. If the response_url has expired, the old prompt stays, still in the thread.
class RefreshDraftPromptJob < ApplicationJob
  queue_as :realtime
  # Saved or dropped since; there is no prompt to redraw.
  discard_on ActiveJob::DeserializationError

  def perform(draft, duration = nil)
    delete_old_prompt(draft)
    LapseTimelapse.sync_if_connected(draft.user)
    project = draft.project
    prompt = SlackMessages.draft_prompt(draft, duration: duration, tracked: TrackedTime.new(draft.user).seconds / 60)
    SlackBot.client.chat_postEphemeral(channel: project.slack_channel_id, user: draft.user.slack_id, thread_ts: project.slack_thread_ts, **prompt)
    draft.update!(prompt_url: nil, prompt_url_at: nil)
  rescue Slack::Web::Api::Errors::SlackError => e
    Rails.logger.warn({ event: "refresh_draft_prompt.failed", draft_id: draft.id, error: e.message }.to_json)
  end

  private

  def delete_old_prompt(draft)
    return unless draft.prompt_live?

    Faraday.post(draft.prompt_url, { delete_original: true }.to_json, "Content-Type" => "application/json")
  rescue Faraday::Error => e
    Rails.logger.warn({ event: "refresh_draft_prompt.delete_failed", draft_id: draft.id, error: e.message }.to_json)
  end
end
