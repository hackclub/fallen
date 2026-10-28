# frozen_string_literal: true

# Turns the few tags a rendered journal uses back into Markdown, for programs that render theirs before we see it.
# Links and images relative to the page are made whole against `base`.
module HtmlMarkdown
  module_function

  def from(node, base:)
    return "" if node.nil?

    node.children.map { |child| markdown_of(child, base) }.join.gsub(/\n{3,}/, "\n\n").strip
  end

  def markdown_of(node, base)
    return node.text if node.text?
    return "" unless node.element?

    inner = node.children.map { |child| markdown_of(child, base) }.join
    case node.name
    when "p", "div" then "#{inner.strip}\n\n"
    when "br" then "\n"
    when /\Ah([1-6])\z/ then "#{'#' * Regexp.last_match(1).to_i} #{inner.strip}\n\n"
    when "strong", "b" then "**#{inner}**"
    when "em", "i" then "*#{inner}*"
    when "code" then node.parent&.name == "pre" ? inner : "`#{inner}`"
    when "pre" then "```\n#{node.text.strip}\n```\n\n"
    when "a" then node["href"].present? ? "[#{inner}](#{absolute(node['href'], base)})" : inner
    when "img" then node["class"].to_s.include?("emote") ? node["alt"].to_s : "![#{node['alt']}](#{absolute(node['src'], base)})"
    when "ul" then node.css("> li").map { "- #{from(it, base:)}\n" }.join + "\n"
    when "ol" then node.css("> li").each_with_index.map { |li, i| "#{i + 1}. #{from(li, base:)}\n" }.join + "\n"
    when "blockquote" then inner.strip.lines.map { "> #{it}" }.join + "\n\n"
    else inner
    end
  end

  # `url` made whole against `base`, or nil if it's blank or not a URL.
  def absolute(url, base)
    url.present? ? URI.join(base, url.strip).to_s : nil
  rescue URI::Error
    nil
  end
  private_class_method :markdown_of
end
