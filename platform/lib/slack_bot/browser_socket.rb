# frozen_string_literal: true

require "openssl"
require "socket"
require "websocket/driver"

module SlackBot
  # The real-time socket Slack's own clients use, signed in as a person with their browser session (an `xoxc-`
  # token and the `d` cookie). It carries events the Events API never sends, like `user_typing`. Those events
  # only arrive for conversations that person is in.
  #
  #   SlackBot::BrowserSocket.new(token: "xoxc-…", cookie: "xoxd-…").run { |event| … }
  #
  # Reconnects with backoff forever; `run` only returns when the process is stopped.
  class BrowserSocket
    URL = "wss://wss-primary.slack.com/"
    PING_EVERY = 30
    DEAD_AFTER = 90
    MAX_BACKOFF = 30

    Connection = Struct.new(:url, :io) do
      def write(data) = io.write(data)
    end

    def initialize(token:, cookie:, logger: SlackBot.logger)
      @token = token
      @cookie = cookie
      @logger = logger
    end

    def run(&block)
      @attempt = 0
      loop do
        connect_and_read(&block)
      rescue IOError, SystemCallError, OpenSSL::SSL::SSLError, SocketError, Timeout::Error => e
        delay = [ 2**@attempt, MAX_BACKOFF ].min
        @attempt += 1
        @logger.warn({ event: "slack_bot.browser_socket.disconnected", error: e.message, retry_in: delay }.to_json)
        sleep delay
      end
    end

    private

    def connect_and_read
      uri = URI(URL)
      io = open_tls(uri.host)
      driver = WebSocket::Driver.client(Connection.new("#{URL}?#{{ token: @token }.to_query}", io))
      driver.set_header("Cookie", "d=#{@cookie}")
      closed = nil
      driver.on(:close) { |close| closed = "socket closed (#{close.code} #{close.reason})" }
      driver.on(:error) { |error| closed = error.message }
      driver.on(:message) do |message|
        event = JSON.parse(message.data) rescue nil
        next unless event.is_a?(Hash)

        case event["type"]
        when "hello"
          @attempt = 0
          @logger.info({ event: "slack_bot.browser_socket.connected" }.to_json)
        when "error"
          @logger.error({ event: "slack_bot.browser_socket.error", error: event["error"] }.to_json)
        end
        yield event
      end
      driver.start

      last_seen = last_ping = monotonic
      until closed
        if io.to_io.wait_readable(PING_EVERY) || io.pending.positive?
          driver.parse(io.readpartial(16_384))
          last_seen = monotonic
        end
        raise IOError, "no data for #{DEAD_AFTER}s" if monotonic - last_seen > DEAD_AFTER
        if monotonic - last_ping >= PING_EVERY
          driver.text({ id: (last_ping = monotonic).to_i, type: "ping" }.to_json)
        end
      end
      raise IOError, closed
    ensure
      io&.close
    end

    def open_tls(host)
      tcp = Socket.tcp(host, 443, connect_timeout: 10)
      context = OpenSSL::SSL::SSLContext.new
      context.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
      ssl = OpenSSL::SSL::SSLSocket.new(tcp, context)
      ssl.hostname = host
      ssl.sync_close = true
      ssl.connect
      ssl.post_connection_check(host)
      ssl
    end

    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
