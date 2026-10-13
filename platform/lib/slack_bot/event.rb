# frozen_string_literal: true

module SlackBot
  # Events API callback. app/bot/app_mention_event.rb handles the "app_mention" event, etc.
  # Events run in SlackEventJob, so take your time; `say` and `reply` are the usual ways to answer.
  class Event < Handler
    class << self
      def event_type = name.delete_suffix("Event").underscore

      # Event names for the manifest. "message" events come per conversation type, so a MessageEvent
      # declares `subscribes_to "message.channels", "message.groups"`.
      def subscribes_to(*names)
        @subscriptions = names.flatten if names.any?
        @subscriptions || [ event_type ]
      end
    end

    def event = payload.event
    def event_type = event.type
    def subtype = event.subtype
    def ts = event.ts
    def thread_ts = event.thread_ts || event.ts
    def channel_id = event.channel || super
    def slack_user_id = event.user || super
    def text = event.text.to_s

    # True for messages posted by bots (including this one). Usually you want to ignore them.
    def from_bot? = event.bot_id.present? || subtype == "bot_message"

    # Posts in the thread of the triggering message.
    def reply(text = nil, blocks: nil, **options) = say(text, blocks: blocks, thread_ts: thread_ts, **options)

    def react(emoji, timestamp: ts) = client.reactions_add(channel: channel_id, name: emoji, timestamp: timestamp)
  end
end
