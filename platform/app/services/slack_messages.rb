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

  EGG_TEASERS = {
    "lulu" => "https://cdn.hackclub.com/01a14bd9-eba7-7b6c-832b-b10a6790a3c4/egg-teaser-lulu.webp",
    "sami" => "https://cdn.hackclub.com/01a14bd9-ea8d-7374-9d4c-2abb6b5428f7/egg-teaser-sami.webp"
  }.freeze

  # Sent once the first journal from Slack hatches the egg, as a DM and in the project's thread (EggCrackingJob). The button opens the site, which plays the hatch.
  def egg_cracking(pet)
    text = ":eyes_shaking: SOMETHING IS CRACKING..."
    crack = SlackBot::Blocks.button(":bangbang:CLICK ME:bangbang:", "open_fallen", url: hatch_url, style: "primary")
    { text: text, blocks: [ SlackBot::Blocks.section(text), SlackBot::Blocks.image(EGG_TEASERS.fetch(pet), "Your egg, cracking"), SlackBot::Blocks.actions(crack) ] }
  end

  # Posted as the pet itself in the thread of the first journal, once its hatch has been watched on the site
  # (HatchCelebrationJob). Needs the chat:write.customize scope for the name and picture.
  def hatch_celebration(pet)
    text = <<~TEXT.strip
      :yay-cat: YAY YOU DID IT!! :yay-cat:

      :bangbang: Congrats on finishing your first journal!! :pleading: in the future, journal in this thread! you can also chat with others in this thread - just click "not a journal" if i ask you if it's a journal.

      Remember to attach images for each journal!!

      - #{pet}

      *p.s. check your mail! we have a note for you :3c:*
    TEXT
    { text: text, **pet_persona(pet) }
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
    return needs_photo_prompt(draft) if draft.files.empty?

    blocks = [ SlackBot::Blocks.section(":notebook_with_decorative_cover: Is this a journal for *#{escape(draft.project.title)}*?\n#{quote(draft.text, 1500)}") ]
    blocks += photo_blocks(draft)
    blocks << SlackBot::Blocks.input("Time spent", SlackBot::Blocks.plain_text_input("duration", placeholder: "Hours, like 1.5 or 0.5", initial_value: duration.presence), block_id: "duration", hint: "Every journal needs one, and a photo for every #{Journal::MINUTES_PER_IMAGE / 60} hours of it. Post photos in the thread to add them.")
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

  # Every journal needs a photo, so writing without one gets a reminder instead of the time box.
  def needs_photo_prompt(draft)
    intro = ":frame_with_picture: Journals need a photo, one for every #{Journal::MINUTES_PER_IMAGE / 60} hours. Post one in this thread and I'll ask you about the journal."
    blocks = [ SlackBot::Blocks.section("#{intro}\n#{quote(draft.text, 1500)}"), SlackBot::Blocks.actions(draft_button("Not a journal", "skip", draft)) ]
    { text: "Journals need a photo. Post one in this thread.", blocks: blocks }
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
  def typing_hint(projects, slack_user_id)
    start = SlackBot::Blocks.actions(SlackBot::Blocks.button("Start a project", "open_fallen", url: new_project_url, style: projects.empty? ? "primary" : nil))
    if projects.empty?
      text = "<@#{slack_user_id}>\n:bangbang: DO :bangbang: NOT :bangbang: SEND :bangbang: A :bangbang: MESSAGE :bangbang: HERE!\nYou don't have a project yet!! To create a project, head to fallen.hackclub.com before coming back!!\n:blob_hype: SEE YOU SOON :blob_hype:"
      return { text: text, blocks: [ SlackBot::Blocks.section(text), start ] }
    end

    threads = projects.map { |project| "• <#{project.slack_url}|#{escape(project.title)}>" }
    text = ":notebook_with_decorative_cover: Writing a journal? Reply in your project's thread: (do NOT send a new message here!)\n#{threads.join("\n")}"
    { text: text, blocks: [ SlackBot::Blocks.section(text), SlackBot::Blocks.context("If you want to start a new project, click the button below."), start ] }
  end

  HUDDLE_GOAL_INPUT = "goal"
  HUDDLE_STILL_OPTIONS = { "yes" => "yes!", "other" => "no i'm working on something else", "chill" => "no i'm just chilling" }.freeze

  # Ephemeral in the huddle's thread on every visit, and again every Huddle::REPROMPT_EVERY messages until they
  # answer (HuddlePromptJob). Someone coming back with a goal from earlier is asked whether they are still on it.
  # HuddleGoalAction re-renders it with `error` when the answer is incomplete.
  def huddle_prompt(session, picked: nil, error: nil)
    return huddle_still_prompt(session, picked: picked, error: error) if session.goal.present?

    question = "<@#{session.slack_id}> what are you working on today?"
    blocks = [ SlackBot::Blocks.section(question),
               SlackBot::Blocks.input("Today I'm working on", SlackBot::Blocks.plain_text_input(HUDDLE_GOAL_INPUT, max_length: 500), block_id: HUDDLE_GOAL_INPUT) ]
    blocks << SlackBot::Blocks.context(":warning: #{escape(error)}") if error
    blocks << SlackBot::Blocks.actions(
      SlackBot::Blocks.button("commit!", "huddle_goal:commit", value: session.public_id, style: "primary"),
      SlackBot::Blocks.button("i'm just chilling here rn!", "huddle_goal:chill", value: session.public_id)
    )
    { text: question, blocks: blocks + huddle_signup_blocks(session), **pet_persona(session.user&.pet) }
  end

  # The choices sit in an actions block so picking one reaches HuddleGoalAction straight away, which redraws this
  # with `picked` and shows the box only for "something else". The submit button's value carries the pick.
  def huddle_still_prompt(session, picked: nil, error: nil)
    question = "<@#{session.slack_id}> are you still working on #{escape(session.goal)}?"
    options = HUDDLE_STILL_OPTIONS.map { |value, label| SlackBot::Blocks.option(label, value) }
    radio = SlackBot::Blocks.radio_buttons("huddle_goal:pick", options, initial: options.find { |option| option[:value] == picked })
    blocks = [ SlackBot::Blocks.section(question), SlackBot::Blocks.actions(radio, block_id: session.public_id) ]
    if picked == "other"
      blocks << SlackBot::Blocks.input("Something else", SlackBot::Blocks.plain_text_input(HUDDLE_GOAL_INPUT, max_length: 500), block_id: HUDDLE_GOAL_INPUT)
    end
    blocks << SlackBot::Blocks.context(":warning: #{escape(error)}") if error
    blocks << SlackBot::Blocks.actions(SlackBot::Blocks.button("submit", "huddle_goal:still", value: [ session.public_id, picked ].compact.join(":"), style: "primary"))
    { text: question, blocks: blocks + huddle_signup_blocks(session), **pet_persona(session.user&.pet) }
  end

  # Under the huddle prompt for someone with no Fallen account, or no project yet.
  def huddle_signup_blocks(session)
    user = session.user
    if user.nil?
      [ SlackBot::Blocks.context("You don't have a Fallen account yet! Sign up and start a project to build with us."),
        SlackBot::Blocks.actions(SlackBot::Blocks.button("Sign up for Fallen", "open_fallen", url: app_url)) ]
    elsif !user.projects.kept.exists?
      [ SlackBot::Blocks.context("You don't have a project yet! Start one on Fallen."),
        SlackBot::Blocks.actions(SlackBot::Blocks.button("Start a project", "open_fallen", url: new_project_url)) ]
    else
      []
    end
  end

  def huddle_answer(session)
    text = session.mode == "working" ? ":dart: Working on: #{escape(session.goal)}" : ":heh: Have fun hanging out!"
    { text: text, blocks: [ SlackBot::Blocks.section(text) ] }
  end

  # Posted in the huddle's thread, as their pet, once someone commits to a goal (HuddleCommitJob).
  def huddle_commit(session)
    { text: "<@#{session.slack_id}> is working on #{escape(session.goal)} today!!", **pet_persona(session.user&.pet) }
  end

  # In the new huddle's thread, for the people Slack dropped when it ended the last one (HuddleHandoffJob).
  def huddle_handoff(huddle, slack_ids)
    text = "#{slack_ids.map { |id| "<@#{id}>" }.join(' ')} the huddle hit Slack's 24 hour limit, so there's a new one. Come back in!"
    blocks = [ SlackBot::Blocks.section(text) ]
    blocks << SlackBot::Blocks.actions(SlackBot::Blocks.button("Join the huddle", "open_huddle", url: huddle.slack_url, style: "primary")) if huddle.slack_url
    { text: text, blocks: blocks }
  end

  # Slack fetches icon_url itself, and fallen.hackclub.com sits behind Orchard's login, so the pictures can't be
  # served from the app.
  PET_PFPS = {
    "lulu" => "https://raw.githubusercontent.com/hackclub/fallen/main/platform/public/static-assets/pets/lulu-pfp.png",
    "sami" => "https://raw.githubusercontent.com/hackclub/fallen/main/platform/public/static-assets/pets/sami-pfp.png"
  }.freeze

  # Posts as the pet (needs chat:write.customize), or as the bot when there is none.
  def pet_persona(pet)
    return {} if pet.blank?

    { username: pet.capitalize, icon_url: PET_PFPS.fetch(pet) }
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

  def hatch_url = Rails.application.routes.url_helpers.home_url(hatch: 1, host: ENV.fetch("APP_URL", "http://localhost:3000"))

  def new_project_url = Rails.application.routes.url_helpers.new_project_url(host: ENV.fetch("APP_URL", "http://localhost:3000"))

  def app_url = ENV.fetch("APP_URL", "http://localhost:3000")

  def escape(text) = text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
end
