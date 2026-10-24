# frozen_string_literal: true

module Mcp
  # What goes into `mcp_actions.arguments` and `.result`. Long strings are cut. Results are kept for writes only (what
  # a read answered is still in the database), and never with a person's email or Hack Club Auth id, so the log
  # doesn't become a second copy of them.
  module Scrub
    STRING_LIMIT = 2_000
    RESULT_LIMIT = 10_000
    REDACTED_KEYS = %w[email hcaId hca_id].freeze

    module_function

    def arguments(args)
      args.to_h.to_h { |key, value| [ key.to_s, clip(value.as_json) ] }
    end

    def result(payload, write:)
      return nil unless write

      json = redact(payload.as_json)
      encoded = JSON.generate(json)
      encoded.bytesize <= RESULT_LIMIT ? json : { "truncated" => true, "bytes" => encoded.bytesize }
    end

    def clip(value)
      case value
      when String then value.length > STRING_LIMIT ? "#{value.first(STRING_LIMIT)}… (#{value.length} chars)" : value
      when Array then value.map { clip(it) }
      when Hash then value.transform_values { clip(it) }
      else value
      end
    end

    def redact(value)
      case value
      when Hash then value.to_h { |key, inner| [ key, REDACTED_KEYS.include?(key.to_s) && !inner.nil? ? "[not logged]" : redact(inner) ] }
      when Array then value.map { redact(it) }
      else value
      end
    end
  end
end
