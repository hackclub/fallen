# frozen_string_literal: true

# Pangram (https://www.pangram.com) tells AI-generated writing from human writing. Journals are checked before
# they post (WritingCheck). Set PANGRAM_API_KEY. Billed per 100 words sent.
module Pangram
  class Error < StandardError; end

  # Pay-as-you-go API price, for the cost on /admin/stats.
  CENTS_PER_100_WORDS = 5

  module_function

  def host = ENV.fetch("PANGRAM_HOST", "https://text.external-api.pangram.com")
  def configured? = ENV["PANGRAM_API_KEY"].present?

  # Starts a check and returns its task id.
  def submit(text)
    response = connection.post("/task", { text: text }.to_json)
    raise Error, "Pangram /task failed (#{response.status})" unless response.success?

    JSON.parse(response.body).fetch("task_id")
  end

  # The finished result (fraction_ai, fraction_ai_assisted, windows, ...), or nil while it is still running.
  def result(task_id)
    response = connection.get("/task/#{ERB::Util.url_encode(task_id)}")
    raise Error, "Pangram /task/:id failed (#{response.status})" unless response.success?

    data = JSON.parse(response.body)
    case data["stage"]
    when "STAGE_SUCCESS" then data
    when "STAGE_FAILED" then raise Error, "Pangram couldn't check it: #{data['headline']}"
    end
  end

  def connection
    Faraday.new(url: host, headers: { "x-api-key" => ENV.fetch("PANGRAM_API_KEY", nil), "Content-Type" => "application/json" }) do |f|
      f.options.open_timeout = 5
      f.options.timeout = 10
    end
  end
end
