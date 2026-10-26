# frozen_string_literal: true

# Stardance (https://stardance.hackclub.com), Hack Club's summer program. Its API needs the person's own key and doesn't
# say who owns a project or whether it's hardware, so a project transfer reads the public project page: plain HTML
# with every devlog on it. Avatars are Cachet links with the author's Slack ID in them, which is how a transfer checks
# the project is the person's. Class names are Stardance's own, so a redesign there shows up here as an Error.
module Stardance
  class Error < StandardError; end

  HOST = "stardance.hackclub.com"
  SLACK_ID = %r{cachet\.hackclub\.com/users/([A-Z0-9]+)}
  DEVLOGS = 'article[data-feed-engagement-post-type-value="Post::Devlog"]'

  module_function

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
    raise Error, "Stardance has no project #{ref}" if response.status == 404
    raise Error, "Stardance answered #{response.status}" unless response.success?

    page = Nokogiri::HTML(response.body)
    title = page.at_css(".project-show__panel--read .project-show__title") or raise Error, "Stardance's page had no project title; did it change?"
    devlogs = page.css(DEVLOGS)
    handle = page.at_css(".project-show__panel--read .project-show__author")&.text&.strip
    authors = devlogs.map { |devlog| author(devlog) }.uniq
    owner = authors.find { it["handle"] == handle } || { "handle" => handle }
    {
      "title" => title.text.strip,
      "description" => markdown(page.at_css(".project-show__panel--read .project-show__description")).presence,
      "repo_url" => page.at_css(".project-show__panel--read a.project-show__pill--github")&.[]("href"),
      "demo_url" => nil,
      "status" => nil,
      "hardware" => page.at_css(".project-show__panel--read .project-show__tag--hardware").present?,
      "owner" => { "name" => owner["handle"], "avatar" => owner["avatar"], "slack_id" => owner["slack_id"] },
      "author_slack_ids" => authors.filter_map { it["slack_id"] }.uniq,
      # Devlogs by someone not yet verified are left off the page for visitors, but still counted here.
      "entry_count" => page.at_css(".project-show__panel--read .project-show__stats-num")&.text.to_i,
      "minutes" => nil,
      "entries" => devlogs.map { |devlog| entry(devlog) }.sort_by { it["at"].to_s }
    }.tap { |project| project["minutes"] = project["entries"].sum { it["minutes"] } }
  end

  # "23h 8m 37s logged" in minutes.
  def minutes(text)
    { "h" => 60, "m" => 1, "s" => 1 / 60r }.sum { |unit, per| text.to_s[/(\d+)#{unit}\b/, 1].to_i * per }.floor
  end

  def author(devlog)
    avatar = devlog.at_css("img.feed-post-card__avatar")&.[]("src")
    { "handle" => devlog.at_css(".feed-post-card__author")&.text&.strip, "avatar" => avatar, "slack_id" => avatar.to_s[SLACK_ID, 1] }
  end

  def entry(devlog)
    {
      "ref" => devlog["data-card-link-url-value"].to_s[%r{/devlogs/(\d+)}, 1] || devlog["id"],
      "at" => devlog.at_css("time.feed-post-card__time")&.[]("datetime"),
      "minutes" => minutes(devlog.at_css(".feed-post-card__duration")&.text),
      "body" => markdown(devlog.at_css(".feed-post-card__body.markdown-content")),
      "images" => devlog.css("img.feed-post-card__image").filter_map { absolute(it["src"]) }
    }
  end

  # Stardance renders its Markdown before we see it; this turns the few tags a devlog uses back into Markdown.
  def markdown(node)
    return "" if node.nil?

    node.children.map { |child| markdown_of(child) }.join.gsub(/\n{3,}/, "\n\n").strip
  end

  def markdown_of(node)
    return node.text if node.text?
    return "" unless node.element?

    inner = node.children.map { |child| markdown_of(child) }.join
    case node.name
    when "p", "div" then "#{inner.strip}\n\n"
    when "br" then "\n"
    when /\Ah([1-6])\z/ then "#{'#' * Regexp.last_match(1).to_i} #{inner.strip}\n\n"
    when "strong", "b" then "**#{inner}**"
    when "em", "i" then "*#{inner}*"
    when "code" then node.parent&.name == "pre" ? inner : "`#{inner}`"
    when "pre" then "```\n#{node.text.strip}\n```\n\n"
    when "a" then node["href"].present? ? "[#{inner}](#{absolute(node['href'])})" : inner
    when "img" then node["class"].to_s.include?("emote") ? node["alt"].to_s : "![#{node['alt']}](#{absolute(node['src'])})"
    when "ul" then node.css("> li").map { "- #{markdown(it)}\n" }.join + "\n"
    when "ol" then node.css("> li").each_with_index.map { |li, i| "#{i + 1}. #{markdown(li)}\n" }.join + "\n"
    when "blockquote" then inner.strip.lines.map { "> #{it}" }.join + "\n\n"
    else inner
    end
  end

  # Stardance's own links and photos can be relative to it.
  def absolute(url)
    url.present? ? URI.join("https://#{HOST}/", url.strip).to_s : nil
  rescue URI::Error
    nil
  end

  def connection
    Faraday.new(url: "https://#{HOST}", headers: { "Accept" => "text/html" }) do |f|
      f.options.open_timeout = 5
      f.options.timeout = 15
    end
  end
  private_class_method :author, :entry, :markdown, :markdown_of, :absolute
end
