# frozen_string_literal: true

# Stasis (https://stasis.hackclub.com), Hack Club's hardware YSWS. Its pages are behind a login, but the discover page
# reads a project, and its timeline of work sessions (each in Markdown, with its hours and photos), from a JSON API
# that doesn't need one. Projects hidden from the gallery are not found.
module Stasis
  class Error < StandardError; end

  HOST = "stasis.hackclub.com"

  module_function

  # The project's id in a link to its page (the owner's or the discover page), or nil for any other link.
  def ref_from(url)
    uri = URI.parse(url.to_s.strip)
    uri.host == HOST ? uri.path[%r{\A/dashboard/(?:projects|discover)/([\w-]+)/?\z}, 1] : nil
  rescue URI::InvalidURIError
    nil
  end

  def url(ref) = "https://#{HOST}/dashboard/discover/#{ref}"

  # The project as ProjectTransfer#snapshot keeps it.
  def project(ref)
    project = get("/api/discover/#{ref}")
    sessions = get("/api/discover/#{ref}/timeline")
    entries = Array(sessions).select { it["type"] == "WORK_SESSION" }.map { |item| entry(item) }.sort_by { it["at"].to_s }
    {
      "title" => project["title"],
      "description" => project["description"],
      "repo_url" => project["githubRepo"],
      "demo_url" => nil,
      "status" => project["buildStatus"].in?([ nil, "draft" ]) ? "design #{project['designStatus']}" : "build #{project['buildStatus']}",
      "hardware" => true,
      "owner" => { "name" => project.dig("user", "name"), "avatar" => project.dig("user", "image"), "slack_id" => nil },
      "author_slack_ids" => [],
      "entry_count" => entries.size,
      "minutes" => entries.sum { it["minutes"] },
      "entries" => entries
    }
  end

  def get(path)
    response = connection.get(path)
    raise Error, "Stasis hides this project from its gallery, or it was deleted" if response.status == 404
    raise Error, "Stasis answered #{response.status}" unless response.success?

    JSON.parse(response.body)
  end

  def entry(item)
    session = item["session"] || {}
    media = Array(session["media"])
    videos = media.select { it["type"] == "VIDEO" }.map { "Video: #{it['url']}" }
    {
      "ref" => session["id"].to_s,
      "at" => item["at"],
      "minutes" => (session["hoursClaimed"].to_f * 60).round,
      "body" => [ session["content"], *videos ].compact_blank.join("\n\n"),
      "images" => media.select { it["type"] == "IMAGE" }.pluck("url")
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
