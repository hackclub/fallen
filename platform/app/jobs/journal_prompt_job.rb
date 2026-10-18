# Asks a project's owner what their recent thread replies were: straight away for the first, and for later ones once
# they have stopped posting for JournalDraft::ASK_AFTER. Every reply schedules one; only the one for the latest asks.
class JournalPromptJob < ApplicationJob
  queue_as :slack

  def perform(draft, last_ts)
    return unless draft.last_ts == last_ts

    project = draft.project
    LapseTimelapse.sync_if_connected(draft.user)
    prompt = SlackMessages.draft_prompt(draft, tracked: TrackedTime.new(draft.user).seconds / 60)
    SlackBot.client.chat_postEphemeral(channel: project.slack_channel_id, user: draft.user.slack_id, thread_ts: project.slack_thread_ts, **prompt)
  rescue Slack::Web::Api::Errors::SlackError
    nil
  end
end
