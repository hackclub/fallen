# frozen_string_literal: true

module Mcp
  # A tool declining to do something for a reason the caller can act on. Logged as an error, never reported as a
  # crash. Raised through Mcp::Context#refuse!.
  class Refused < StandardError; end
end
