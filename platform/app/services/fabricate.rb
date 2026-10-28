# frozen_string_literal: true

# Fabricate (https://fabricate.hackclub.com), Hack Club's hardware YSWS. Its API has no journals and no way to find
# someone's projects, so a project transfer reads the public project page instead: it's an Inertia page, so the props
# it renders with (the project and every journal entry) are JSON in the HTML. Unlisted and deleted projects redirect.
module Fabricate
  class Error < StandardError; end

  HOST = "fabricate.hackclub.com"

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
    raise Error, "Fabricate shows this project only to its owner, or it was deleted" if response.status.in?([ 301, 302, 404 ])
    raise Error, "Fabricate answered #{response.status}" unless response.success?

    props = InertiaPage.from(response.body)&.dig("props") or raise Error, "Fabricate's page had no Inertia props; did it change?"
    project = props["project"] or raise Error, "Fabricate's page had no project on it"
    {
      "title" => project["name"],
      "description" => project["description"],
      "repo_url" => project["repo_link"],
      "demo_url" => project["demo_link"],
      "status" => project["status"],
      "hardware" => true,
      "owner" => { "name" => project["user_display_name"], "avatar" => project["user_avatar"], "slack_id" => nil },
      "author_slack_ids" => [],
      "entry_count" => Array(props["entries"]).size,
      "minutes" => project["effective_seconds"].to_i / 60,
      "entries" => Array(props["entries"]).map { |entry| entry(entry) }.sort_by { it["at"].to_s }
    }
  end

  def entry(entry)
    body = [ entry["title"].presence && "**#{entry['title']}**", entry["body"] ].compact_blank.join("\n\n")
    body = [ body, "Timelapse: #{entry['timelapse_url']}" ].join("\n\n") if entry["timelapse_url"].present?
    {
      "ref" => entry["id"].to_s,
      "at" => entry["created_at_iso"],
      "minutes" => entry["effective_seconds"].to_i / 60,
      "body" => body,
      "images" => Array(entry["image_urls"])
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
