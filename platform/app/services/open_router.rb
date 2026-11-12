# frozen_string_literal: true

# OpenRouter (https://openrouter.ai): one OpenAI-compatible API in front of every model provider. Set
# OPENROUTER_API_KEY. Used for reading bills of materials (BomExtraction). Slow (a model writing a whole answer):
# call it from a job.
module OpenRouter
  class Error < StandardError; end

  HOST = "https://openrouter.ai"

  module_function

  def configured? = ENV["OPENROUTER_API_KEY"].present?

  # The model's answer to `system` + `user` as a Hash matching the JSON `schema` (strict structured output). Only
  # providers that support structured output are used, and none that keep or train on what's sent.
  def json(model:, system:, user:, schema:, max_tokens:, effort: nil)
    response = connection.post("/api/v1/chat/completions", {
      model:, max_tokens:, **({ reasoning: { effort: } } if effort),
      messages: [ { role: "system", content: system }, { role: "user", content: user } ],
      response_format: { type: "json_schema", json_schema: { name: "answer", strict: true, schema: } },
      provider: { require_parameters: true, data_collection: "deny" }
    }.to_json)
    raise Error, "OpenRouter failed (#{response.status}): #{response.body.to_s.truncate(300)}" unless response.success?

    body = JSON.parse(response.body)
    raise Error, "OpenRouter failed: #{body.dig("error", "message").to_s.truncate(300)}" if body["error"]

    choice = body.dig("choices", 0)
    raise Error, "The model stopped early (#{choice&.dig("finish_reason")})" unless choice&.dig("finish_reason") == "stop"

    JSON.parse(choice.dig("message", "content").to_s)
  rescue JSON::ParserError => e
    raise Error, "The model's answer wasn't JSON: #{e.message}"
  rescue Faraday::Error => e
    raise Error, "OpenRouter couldn't be reached: #{e.message}"
  end

  def connection
    Faraday.new(url: HOST, headers: { "Authorization" => "Bearer #{ENV.fetch("OPENROUTER_API_KEY", nil)}", "Content-Type" => "application/json",
      "X-Title" => "Fallen" }) do |f|
      f.options.open_timeout = 10
      f.options.timeout = 240
    end
  end
end
