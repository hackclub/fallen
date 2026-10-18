# frozen_string_literal: true

require "faraday"

module SlackBot
  # Slack's Web API called the way Slack's own clients call it, signed in as a person with their browser session
  # (an `xoxc-` token and the `d` cookie). It reaches the undocumented methods behind huddles that bot and user
  # OAuth tokens cannot (`rooms.join`, `screenhero.rooms.info`). Companion to BrowserSocket.
  #
  #   SlackBot::BrowserClient.new(token: "xoxc-…", cookie: "xoxd-…").call("auth.test")["user_id"]
  class BrowserClient
    URL = "https://slack.com"

    class Error < StandardError
      attr_reader :code

      def initialize(method, code)
        @code = code
        super("#{method} failed: #{code}")
      end
    end

    def initialize(token:, cookie:, url: URL)
      @token = token
      @cookie = cookie
      @url = url
    end

    # Posts a form like the desktop client does and returns the parsed body. Raises Error with Slack's error code
    # when `ok` is false.
    def call(method, **fields)
      response = connection.post("/api/#{method}", fields.merge(token: @token))
      raise Error.new(method, "http_#{response.status}") unless response.success?

      body = JSON.parse(response.body)
      raise Error.new(method, body["error"] || "unknown_error") unless body["ok"]

      body
    end

    private

    def connection
      @connection ||= Faraday.new(url: @url, headers: { "Cookie" => "d=#{@cookie}" }) do |f|
        f.request :url_encoded
        f.options.timeout = 30
        f.options.open_timeout = 5
      end
    end
  end
end
