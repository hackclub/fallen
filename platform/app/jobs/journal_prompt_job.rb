# Asks a project's owner what their recent thread replies were: straight away for the first, and for later ones once
# they have stopped posting for JournalDraft::ASK_AFTER. Every reply schedules one; only the one for the latest asks.
class JournalPromptJob < ApplicationJob
  queue_as :slack

  def perform(draft, last_ts)
    return unless draft.last_ts == last_ts

    project = draft.project
    refresh_lapse(draft.user)
    prompt = SlackMessages.draft_prompt(draft, tracked: TrackedTime.new(draft.user).seconds / 60)
    SlackBot.client.chat_postEphemeral(channel: project.slack_channel_id, user: draft.user.slack_id, thread_ts: project.slack_thread_ts, **prompt)
  rescue Slack::Web::Api::Errors::SlackError
    nil
  end

  private

  # A fresh copy of their timelapses for the prompt to list, like the web composer asks for when it opens. The
  # prompt still goes out with the last copy if Lapse is slow or down.
  def refresh_lapse(user)
    LapseTimelapse.sync(user) if user.lapse_connected?
  rescue Lapse::Error, Faraday::Error => e
    Rails.logger.warn({ event: "journal_prompt.lapse_sync_failed", user_id: user.id, error: e.message }.to_json)
  end
end
