# frozen_string_literal: true

module SlackBot
  # Reactions as status markers on people's messages. Failures (already reacted, message gone) are not errors.
  module Reactions
    module_function

    def add(channel, ts, emoji)
      SlackBot.client.reactions_add(channel: channel, timestamp: ts, name: emoji)
    rescue Slack::Web::Api::Errors::AlreadyReacted, Slack::Web::Api::Errors::MessageNotFound
      nil
    end

    def remove(channel, ts, emoji)
      SlackBot.client.reactions_remove(channel: channel, timestamp: ts, name: emoji)
    rescue Slack::Web::Api::Errors::NoReaction, Slack::Web::Api::Errors::MessageNotFound
      nil
    end

    def swap(channel, ts, from:, to:)
      remove(channel, ts, from)
      add(channel, ts, to)
    end
  end
end
