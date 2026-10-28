# frozen_string_literal: true

# Fallout (https://fallout.hackclub.com), Hack Club's hardware YSWS. A project's page opens as a modal over the
# bulletin board, so a transfer asks for it the way that page does: an Inertia request, which answers with the page's
# props as JSON (the project and every journal entry, in HTML). Inertia wants the app's current asset version with
# it, which the landing page carries. A project's hours include time logged outside its entries.
module Fallout
  class Error < StandardError; end

  HOST = "fallout.hackclub.com"

  module_function

  # The project's id in a link to its page (or the bulletin board opened on it), or nil for any other link.
  def ref_from(url)
    uri = URI.parse(url.to_s.strip)
    return nil unless uri.host == HOST

    uri.path[%r{\A/projects/(\d+)/?\z}, 1] || (uri.path.match?(%r{\A/bulletin_board/?\z}) && uri.query.to_s[/(?:\A|&)project=(\d+)/, 1]) || nil
  rescue URI::InvalidURIError
    nil
  end

  def url(ref) = "https://#{HOST}/projects/#{ref}"

  # The project as ProjectTransfer#snapshot keeps it.
  def project(ref)
    response = connection.get("/projects/#{ref}") { it.headers.merge!("X-Inertia" => "true", "X-Inertia-Version" => version.to_s) }
    raise Error, "Fallout shows this project only to its owner, or it was deleted" if response.status.in?([ 301, 302, 404 ])
    raise Error, "Fallout answered #{response.status}" unless response.success?

    props = JSON.parse(response.body)["props"] || {}
    project = props["project"] or raise Error, "Fallout's page had no project on it"
    entries = Array(props["journal_entries"]).map { |entry| entry(entry) }.sort_by { it["at"].to_s }
    {
      "title" => project["name"],
      "description" => project["description"],
      "repo_url" => project["repo_link"],
      "demo_url" => project["demo_link"],
      "status" => Array(props["ships"]).max_by { it["created_at_iso"].to_s }&.dig("status"),
      "hardware" => true,
      "owner" => { "name" => project["user_display_name"], "avatar" => project["user_avatar"], "slack_id" => nil },
      "author_slack_ids" => [],
      "entry_count" => entries.size,
      "minutes" => project["time_logged"].to_i / 60,
      "entries" => entries
    }
  end

  def version
    response = connection.get("/")
    raise Error, "Fallout answered #{response.status}" unless response.success?

    InertiaPage.from(response.body)&.dig("version") or raise Error, "Fallout's page had no Inertia version; did it change?"
  end

  def entry(entry)
    {
      "ref" => entry["id"].to_s,
      "at" => entry["created_at_iso"],
      "minutes" => entry["time_logged"].to_i / 60,
      "body" => HtmlMarkdown.from(Nokogiri::HTML.fragment(entry["content_html"].to_s), base: "https://#{HOST}/"),
      "images" => Array(entry["images"])
    }
  end

  def connection
    Faraday.new(url: "https://#{HOST}", headers: { "Accept" => "text/html, application/json" }) do |f|
      f.options.open_timeout = 5
      f.options.timeout = 15
    end
  end
  private_class_method :version, :entry
end
