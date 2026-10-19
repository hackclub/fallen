# Edits the last of the Slack replies a journal was made from to add SlackMessages.footer, linking to the journal
# on the site. The edit is made as the person (their user token) and keeps their text and blocks as they wrote them,
# so MessageEvent#message_changed sees the same text and leaves the journal alone.
class AddJournalFooterJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(journal)
    return if journal.discarded? || !journal.from_slack? || !journal.on_slack? || !journal.user.slack_connected?

    ts = journal.last_slack_ts
    message = find_message(journal, ts) or return
    return if SlackMessages.footer?(message.blocks)

    blocks = Array(message.blocks).map(&:to_h) + [ SlackMessages.footer(SlackMessages.journal_url(journal)) ]
    SlackMessaging.update(journal.user, channel: journal.slack_channel_id, ts: ts, text: message.text.to_s, blocks: blocks, by_bot: false)
  rescue Slack::Web::Api::Errors::CantUpdateMessage, Slack::Web::Api::Errors::MessageNotFound, Slack::Web::Api::Errors::EditWindowClosed
    nil
  end

  private

  def find_message(journal, ts)
    replies = SlackBot.client.conversations_replies(channel: journal.slack_channel_id, ts: journal.project.slack_thread_ts, oldest: ts, latest: ts, inclusive: true)
    Array(replies.messages).find { |message| message.ts == ts }
  rescue Slack::Web::Api::Errors::ThreadNotFound
    nil
  end
end
