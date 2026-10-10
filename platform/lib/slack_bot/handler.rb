# frozen_string_literal: true

module SlackBot
  class Handler
    include SlackBot::Blocks

    attr_reader :payload

    def initialize(payload)
      @payload = payload
      @inline_response = nil
      @responded = false
    end

    # Runs the handler and returns the inline HTTP response (or nil for a plain 200 ack).
    def run
      call
      @inline_response
    end

    def call
      raise NotImplementedError, "#{self.class.name} must implement #call"
    end

    # --- context -------------------------------------------------------------------------------

    def client = SlackBot.client
    def team_id = payload.team_id || payload.dig("team", "id")
    def slack_user_id = payload.user_id || payload.dig("user", "id")
    def channel_id = payload.channel_id || payload.dig("channel", "id")
    def trigger_id = payload.trigger_id
    def response_url = payload.response_url

    # The signed-up User whose Slack account sent this payload (nil if they never signed in).
    def user
      return @user if defined?(@user)

      @user = slack_user_id.present? ? User.kept.find_by(slack_id: slack_user_id) : nil
    end

    # --- replying ------------------------------------------------------------------------------

    # Posts a message (chat.postMessage). Defaults to the channel this payload came from.
    def say(text = nil, channel: channel_id, thread_ts: nil, blocks: nil, **options)
      client.chat_postMessage({ channel: channel, text: text, blocks: blocks, thread_ts: thread_ts, **options }.compact)
    end

    # Message only the triggering user can see (chat.postEphemeral).
    def ephemeral(text = nil, channel: channel_id, user: slack_user_id, blocks: nil, thread_ts: nil, **options)
      client.chat_postEphemeral({ channel: channel, user: user, text: text, blocks: blocks, thread_ts: thread_ts, **options }.compact)
    end

    # Replies through Slack's response_url. First call during a slash command is returned inline as the ack;
    # later calls (or any call from an action/shortcut) are POSTed to response_url.
    def respond(text = nil, blocks: nil, in_channel: false, replace_original: nil, delete_original: nil, **options)
      body = {
        text: text, blocks: blocks,
        response_type: in_channel ? "in_channel" : "ephemeral",
        replace_original: replace_original, delete_original: delete_original,
        **options
      }.compact

      if inline_response_allowed? && !@responded
        @inline_response = body
      else
        raise ArgumentError, "No response_url on this payload" if response_url.blank?

        Faraday.post(response_url, body.to_json, "Content-Type" => "application/json")
      end
      @responded = true
      body
    end

    def open_modal(view, trigger_id: self.trigger_id) = client.views_open(trigger_id: trigger_id, view: view)
    def update_modal(view, view_id: payload.dig("view", "id")) = client.views_update(view_id: view_id, view: view)
    def push_modal(view, trigger_id: self.trigger_id) = client.views_push(trigger_id: trigger_id, view: view)

    private

    def inline_response_allowed? = false
    def respond_inline(body) = @inline_response = body
  end
end
