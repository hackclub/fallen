# frozen_string_literal: true

# Macondo (https://macondo.hackclub.com), a Hack Club YSWS. Its own API reads a project and its journals without
# signing in. A software project's hours come from Hackatime, so its journals mostly log none; the hours Hackatime
# counted are on its ships, each the project's running total when it was shipped.
module Macondo
  class Error < StandardError; end

  HOST = "macondo.hackclub.com"
  VIDEO = /!\[video\]\(/i

  module_function

  # The project's id in a link to its page, or nil for any other link.
  def ref_from(url)
    uri = URI.parse(url.to_s.strip)
    uri.host == HOST ? uri.path[%r{\A/projects/(\d+)/?\z}, 1] : nil
  rescue URI::InvalidURIError
    nil
  end

  def url(ref) = "https://#{HOST}/projects/#{ref}"

  # The project as ProjectTransfer#snapshot keeps it.
  def project(ref)
    project = get("/api/projects/#{ref}")
    ship = Array(get("/api/projects/#{ref}/ships")).max_by { it["created_at"].to_s }
    journals = Array(project["journals"]).reject { it["archived"] }
    owner = project["owner"] || {}
    entries = journals.map { |journal| entry(journal) }.sort_by { it["at"].to_s }
    {
      "title" => project["name"],
      "description" => project["description"],
      "repo_url" => project["repository_url"],
      "demo_url" => project["demo_url"],
      "status" => ship&.dig("status"),
      "hardware" => project["type"] == "hardware",
      "owner" => { "name" => owner["username"], "avatar" => owner["image"], "slack_id" => owner["slack_id"] },
      "author_slack_ids" => [ owner["slack_id"], *journals.map { it["author_slack_id"] } ].compact_blank.uniq,
      "entry_count" => journals.size,
      "minutes" => [ entries.sum { it["minutes"] }, (ship&.dig("hackatime_hours").to_f * 60).round ].max,
      "entries" => entries
    }
  end

  def get(path)
    response = connection.get(path)
    raise Error, "Macondo has no project at #{path}" if response.status == 404
    raise Error, "Macondo answered #{response.status}" unless response.success?

    JSON.parse(response.body)
  end

  # Videos are written as images with "video" for their text; they stay links instead of becoming photos.
  def entry(journal)
    body = journal["long_brief"].to_s.gsub(VIDEO, "[Video](")
    {
      "ref" => journal["id"].to_s,
      "at" => journal["created_at"],
      "minutes" => (journal["hours"].to_f * 60).round,
      "body" => [ journal["short_brief"].presence && "**#{journal['short_brief']}**", body ].compact_blank.join("\n\n"),
      "images" => []
    }
  end

  def connection
    Faraday.new(url: "https://#{HOST}", headers: { "Accept" => "application/json" }) do |f|
      f.options.open_timeout = 5
      f.options.timeout = 15
    end
  end
  private_class_method :get, :entry
end
