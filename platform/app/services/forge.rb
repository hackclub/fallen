# frozen_string_literal: true

# Forge (https://forge.hackclub.com), Hack Club's hardware YSWS. A project's public page is an Inertia page, so the
# props it renders with (the project and every devlog, in Markdown) are JSON in the HTML, as on Fabricate. Devlogs
# say only the day they were written, and unlisted projects redirect.
module Forge
  class Error < StandardError; end

  HOST = "forge.hackclub.com"

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
    response = connection.get("/projects/#{ref}")
    raise Error, "Forge shows this project only to its team, or it was deleted" if response.status.in?([ 301, 302, 404 ])
    raise Error, "Forge answered #{response.status}" unless response.success?

    props = InertiaPage.from(response.body)&.dig("props") or raise Error, "Forge's page had no Inertia props; did it change?"
    project = props["project"] or raise Error, "Forge's page had no project on it"
    owner = Array(project["members"]).find { it["is_owner"] } || {}
    entries = Array(props["devlogs"]).map { |devlog| entry(devlog) }.sort_by { [ it["at"].to_s, it["ref"].to_i ] }
    {
      "title" => project["name"],
      "description" => project["subtitle"],
      "repo_url" => project["repo_link"],
      "demo_url" => nil,
      "status" => project["status"],
      "hardware" => true,
      "owner" => { "name" => owner["display_name"], "avatar" => owner["avatar"], "slack_id" => nil },
      "author_slack_ids" => [],
      "entry_count" => entries.size,
      "minutes" => entries.sum { it["minutes"] },
      "entries" => entries
    }
  end

  def entry(devlog)
    body = [ devlog["title"].presence && "**#{devlog['title']}**", devlog["content"] ].compact_blank.join("\n\n")
    lapses = Array(devlog["lapse_urls"]).compact_blank
    body = [ body, *lapses.map { "Timelapse: #{it}" } ].join("\n\n") if lapses.any?
    {
      "ref" => devlog["id"].to_s,
      "at" => (Date.parse(devlog["created_at"].to_s).iso8601 rescue nil),
      "minutes" => (devlog["time_hours"].to_f * 60).round,
      "body" => body,
      "images" => []
    }
  end

  def connection
    Faraday.new(url: "https://#{HOST}", headers: { "Accept" => "text/html" }) do |f|
      f.options.open_timeout = 5
      f.options.timeout = 15
    end
  end
  private_class_method :entry
end
