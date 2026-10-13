# frozen_string_literal: true

# The text and blocks of the messages Fallen writes into the journals channel.
module SlackMessages
  extend SlackBot::Blocks

  module_function

  def project_anchor(project)
    lines = [ ":hammer_and_wrench: *#{escape(project.title)}*" ]
    lines << escape(project.description) if project.description.present?
    links = [ project.repo_url.presence && "<#{project.repo_url}|repo>", project.demo_url.presence && "<#{project.demo_url}|demo>" ].compact
    lines << links.join(" · ") if links.any?
    { text: lines.join("\n") }
  end

  def journal(journal)
    body = mrkdwn(journal.body)
    image_links = journal.images.map { |image| "<#{blob_url(image)}|:frame_with_picture: #{image.filename}>" }
    footer = [
      journal.hours_logged? && ":stopwatch: #{journal.duration_text}",
      journal.lapse_url.presence && "<#{journal.lapse_url}|:movie_camera: timelapse>",
      "<#{project_url(journal.project)}|fallen>"
    ].select(&:present?)
    text = [ body, image_links.join("  ") ].select(&:present?).join("\n")
    { text: text, blocks: [ SlackBot::Blocks.section(text), SlackBot::Blocks.context(footer.join("  ·  ")) ] }
  end

  # Enough of Markdown to read well in Slack: bold, italics, strike, code, links, images, headings, lists.
  def mrkdwn(markdown)
    text = escape(markdown)
    text = text.gsub(/!\[([^\]]*)\]\(([^)\s]+)\)/) { "<#{$2}|#{$1.presence || 'image'}>" }
    text = text.gsub(/\[([^\]]+)\]\(([^)\s]+)\)/) { "<#{$2}|#{$1}>" }
    text = text.gsub(/\*\*(.+?)\*\*/, "\u0000\\1\u0000").gsub(/__(.+?)__/, "\u0000\\1\u0000")
    text = text.gsub(/(?<![*\w])\*(?!\*)([^*\n]+?)\*(?!\*)/, '_\1_')
    text = text.tr("\u0000", "*")
    text = text.gsub(/~~(.+?)~~/, '~\1~')
    text = text.gsub(/^\#{1,6}\s+(.+)$/, '*\1*')
    text.gsub(/^\s*[-*]\s+/, "• ").gsub(/^\s*(\d+)\.\s+/, '\1. ')
  end

  def blob_url(image) = Rails.application.routes.url_helpers.rails_blob_url(image, host: ENV.fetch("APP_URL", "http://localhost:3000"))

  def project_url(project) = Rails.application.routes.url_helpers.project_url(project, host: ENV.fetch("APP_URL", "http://localhost:3000"))

  def escape(text) = text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
end
