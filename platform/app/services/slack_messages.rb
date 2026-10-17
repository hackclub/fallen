# frozen_string_literal: true

# The text and blocks of the messages Fallen writes into the journals channel.
module SlackMessages
  module_function

  def project_anchor(project)
    lines = [ ":hammer_and_wrench: *#{escape(project.title)}*" ]
    lines << escape(project.description) if project.description.present?
    { text: lines.join("\n") }
  end

  def journal(journal)
    body = mrkdwn(journal.body)
    image_links = journal.images.map { |image| "<#{blob_url(image)}|:frame_with_picture: #{image.filename}>" }
    text = [ body, image_links.join("  ") ].select(&:present?).join("\n")
    blocks = [ SlackBot::Blocks.section(text) ]
    # Timelapses are private to the person and staff, so the public thread never links one.
    blocks << SlackBot::Blocks.context(":stopwatch: #{journal.duration_text}") if journal.hours_logged?
    { text: text, blocks: blocks }
  end

  def stray_post(text, removed:)
    cta = "If you're looking to start a new project, visit the Fallen platform!"
    start = SlackBot::Blocks.actions(SlackBot::Blocks.button("Start a new project here", "open_fallen", url: new_project_url, style: "primary"))
    return { text: cta, blocks: [ SlackBot::Blocks.section(cta), start ] } unless removed

    intro = ":wastebasket: Hiya! We removed your post from the journals channel! This channel is for journalling for Fallen projects only."
    intro += "\nHere is what you wrote:\n#{escape(text.truncate(2000)).gsub(/^/, '> ')}" if text.present?
    { text: "#{intro}\n#{cta}", blocks: [ SlackBot::Blocks.section(intro), SlackBot::Blocks.section(cta), start ] }
  end

  # Ephemeral, asking a project's owner what their recent thread replies were (JournalPromptJob). Everything happens
  # in the message: the time box and buttons sit under the text, and JournalDraftAction re-renders it with `error`
  # and what they typed when the time doesn't parse.
  def draft_prompt(draft, duration: nil, lapse_url: nil, error: nil)
    return photos_prompt(draft) unless draft.written?

    blocks = [ SlackBot::Blocks.section(":notebook_with_decorative_cover: Is this a journal for *#{escape(draft.project.title)}*?\n#{quote(draft.text, 1500)}") ]
    blocks += photo_blocks(draft)
    blocks << SlackBot::Blocks.input("Time spent", SlackBot::Blocks.plain_text_input("duration", placeholder: "1h 45m, 2.5, 50m…", initial_value: duration.presence), block_id: "duration", hint: "Every journal needs one. However you'd write it.")
    blocks << SlackBot::Blocks.input("Timelapse", SlackBot::Blocks.plain_text_input("lapse_url", placeholder: "https://lapse.hackclub.com/...", initial_value: lapse_url.presence), block_id: "lapse_url", optional: true)
    blocks << SlackBot::Blocks.context(":warning: #{escape(error)}") if error
    blocks << SlackBot::Blocks.actions(
      draft_button("Save journal", "journal", draft, style: "primary"),
      draft_button("Add more", "more", draft),
      draft_button("Not a journal", "skip", draft)
    )
    blocks << SlackBot::Blocks.context("#{draft_counts(draft)}. Anything else you post here joins it until you pick.")
    { text: "Is this a journal for #{draft.project.title}?", blocks: blocks }
  end

  def photos_prompt(draft)
    count = draft.files.size
    photos = count == 1 ? "this photo" : "these #{count} photos"
    previous = draft.previous_journal
    buttons = [
      (draft_button("Add to last journal", "attach", draft) if previous),
      draft_button("Save for my next one", "more", draft, style: previous ? nil : "primary"),
      draft_button("Skip", "skip", draft)
    ].compact
    blocks = [ SlackBot::Blocks.section(":frame_with_picture: Want #{photos} in a journal for *#{escape(draft.project.title)}*?"), *photo_blocks(draft), SlackBot::Blocks.actions(*buttons) ]
    blocks << SlackBot::Blocks.context("Last journal (#{previous.created_at.to_date.to_fs(:long)}): #{(previous.from_slack? ? previous.body : escape(previous.body)).squish.truncate(120)}") if previous
    { text: "Want #{photos} in a journal?", blocks: blocks }
  end

  PROMPT_PHOTOS = 3
  PICKER_INPUT = "draft_parts"
  # Slack allows ten options per checkbox group, so longer drafts get several.
  PICKER_GROUP = 10

  # Replaces a draft prompt when "Not a journal" is pressed on several messages, so the person can keep some.
  def draft_picker(draft)
    groups = draft.parts.each_slice(PICKER_GROUP).each_with_index.map do |parts, index|
      options = parts.map { |part| { text: SlackBot::Blocks.mrkdwn(part_label(part)), value: part["ts"] } }
      SlackBot::Blocks.input(index.zero? ? "Which of these are part of the journal?" : "More messages", SlackBot::Blocks.checkboxes("#{PICKER_INPUT}_#{index}", options),
                             block_id: "#{PICKER_INPUT}_#{index}", optional: true)
    end
    done = SlackBot::Blocks.button("Done", "journal_draft:pick", value: "#{draft.public_id}:#{draft.last_ts}", style: "primary")
    blocks = [ *groups, SlackBot::Blocks.actions(done, draft_button("Back", "back", draft)),
               SlackBot::Blocks.context("Unticked messages stay in the thread, they just won't be in a journal. Tick none to drop them all.") ]
    { text: "Which of these are part of the journal?", blocks: blocks }
  end

  def part_label(part)
    text = part["text"].to_s.squish
    photos = Array(part["files"]).size
    text = [ text.presence, (":frame_with_picture: #{photos == 1 ? '1 photo' : "#{photos} photos"}" if photos.positive?) ].compact.join(" ")
    text.presence&.truncate(72) || "(empty message)"
  end

  # Slack shows its own files in image blocks to anyone who can see them, so nothing is downloaded for this.
  def photo_blocks(draft)
    draft.files.first(PROMPT_PHOTOS).map { |file| { type: "image", slack_file: { id: file["id"] }, alt_text: file["name"].presence || "photo" } }
  end

  # The action_id carries the choice and the value the draft, so the buttons in one message stay unique.
  def draft_button(label, choice, draft, style: nil) = SlackBot::Blocks.button(label, "journal_draft:#{choice}", value: draft.public_id, style: style)

  def draft_counts(draft)
    counts = [ draft.message_count == 1 ? "1 message" : "#{draft.message_count} messages" ]
    counts << (draft.files.size == 1 ? "1 photo" : "#{draft.files.size} photos") if draft.files.any?
    counts.join(", ")
  end

  # Slack hands message text over already escaped.
  def quote(text, limit) = text.strip.truncate(limit).gsub(/^/, "> ")

  # Ephemeral, shown while someone types a top-level post in the journals channel (TypingHintJob).
  def typing_hint(projects)
    start = SlackBot::Blocks.actions(SlackBot::Blocks.button("Start a project", "open_fallen", url: new_project_url, style: projects.empty? ? "primary" : nil))
    if projects.empty?
      text = ":bangbang: DO :bangbang: NOT :bangbang: SEND :bangbang: A :bangbang: MESSAGE :bangbang: HERE!\n\nYou don't have a project yet!! To create a project, head to fallen.hackclub.com before coming back!!\n\n:blob_hype: SEE YOU SOON :blob_hype:"
      return { text: text, blocks: [ SlackBot::Blocks.section(text), start ] }
    end

    threads = projects.map { |project| "• <#{project.slack_url}|#{escape(project.title)}>" }
    text = ":notebook_with_decorative_cover: Writing a journal? Reply in your project's thread: (do NOT send a new message here!)\n#{threads.join("\n")}"
    { text: text, blocks: [ SlackBot::Blocks.section(text), SlackBot::Blocks.context("If you want to start a new project, click the button below."), start ] }
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

  def new_project_url = Rails.application.routes.url_helpers.new_project_url(host: ENV.fetch("APP_URL", "http://localhost:3000"))

  def escape(text) = text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
end
