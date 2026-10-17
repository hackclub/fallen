# frozen_string_literal: true

# Prometheus (https://github.com/hackclub/prometheus), Hack Club's Slack moderation bot. Fallen uses its API to
# delete posts in the journals channel that it did not write. PROMETHEUS_API_KEY is a key for that channel, made
# by a channel manager; deletions are logged under their name.
module Prometheus
  class Error < StandardError; end

  module_function

  def host = ENV.fetch("PROMETHEUS_HOST", "https://prometheus.hackclub.com")

  def configured? = ENV["PROMETHEUS_API_KEY"].present?

  # Deletes one message. Prometheus answers 200 even when Slack refused, so the per-message failures are checked
  # too; a message that is already gone counts as deleted.
  def delete_message(ts, reason:)
    response = connection.post("/api/v1/messages/delete", { ts: ts, reason: reason }.to_json)
    raise Error, "Prometheus message delete failed: #{response.status} #{response.body.to_s.truncate(200)}" unless response.success?

    body = JSON.parse(response.body)
    failures = Array(body["failed"]).reject { |failure| failure["error"] == "message_not_found" }
    raise Error, "Prometheus could not delete #{ts}: #{failures.map { |failure| failure['error'] }.join(', ')}" if failures.any?

    body
  end

  def connection
    Faraday.new(url: host, headers: { "Authorization" => "Bearer #{ENV.fetch('PROMETHEUS_API_KEY')}", "Content-Type" => "application/json" }) do |f|
      f.options.timeout = 30
      f.options.open_timeout = 5
    end
  end
end
