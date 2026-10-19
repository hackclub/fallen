# frozen_string_literal: true

# The text and blocks of the messages Fallen writes into the journals channel.
module SlackMessages
  module_function

  def project_anchor(project)
    text = [ "Project name: #{escape(project.title)}", escape(project.description).presence ].compact.join("\n\n")
    { text: text, blocks: [ SlackBot::Blocks.section(text) ] }
  end

  # The photos go under the message as image attachments rather than links, so the ones the editor embedded in the
  # body (as Markdown images pointing at the site) are taken out of the text.
  def journal(journal)
    text = mrkdwn(without_embedded_images(journal.body)).gsub(/\n{3,}/, "\n\n").strip
    blocks = SlackBot::Blocks.sections(text)
    # Timelapses are private to the person and staff, so the public thread never links one.
    blocks << footer(journal_url(journal), *(":stopwatch: #{journal.duration_text}" if journal.hours_logged?))
    attachments = journal.images.map { |image| { fallback: image.filename.to_s, image_url: blob_url(image) } }
    { text: text, blocks: blocks, attachments: attachments }
  end

  FOOTER_BLOCK_ID = "fallen_footer"

  # The small "fallen ↗" line under a journal, linking to it on the site.
  def footer(url, *before) = SlackBot::Blocks.context(*before, "<#{url}|fallen ↗>").merge(block_id: FOOTER_BLOCK_ID)
  def footer?(blocks) = Array(blocks).any? { |block| block.to_h.with_indifferent_access[:block_id] == FOOTER_BLOCK_ID }

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
    TEXT
    ps = "p.s. check your mailbox in a few days! (the physical one) we have a note for you :3c:"
    { text: "#{text}\n\n#{ps}", blocks: [ SlackBot::Blocks.section(text), SlackBot::Blocks.context(ps) ], **pet_persona(pet) }
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
  # and what they typed when the time doesn't parse. `tracked` is the hours the huddle and site timer counted since
  # their last journal, offered in the time box the first time it is shown. Timelapses are picked in a modal
  # (lapse_picker) and kept on the draft.
  def draft_prompt(draft, duration: nil, tracked: nil, error: nil)
    return photos_prompt(draft) unless draft.written?
    short = Journal.written_length(draft.text) < Journal::MIN_BODY_LENGTH
    return needs_more_prompt(draft, tracked: tracked) if short || draft.files.empty?

    blocks = [ SlackBot::Blocks.section(":notebook_with_decorative_cover: Is this a journal for *#{escape(draft.project.title)}*?\n#{quote(draft.text, 1500)}") ]
    blocks += photo_blocks(draft)
    offered = Duration.format(tracked)&.delete_suffix("h") if duration.nil? && tracked.to_i.positive?
    hint = "Every journal needs one, and a photo for every #{Journal::MINUTES_PER_IMAGE / 60} hours of it. Post photos in the thread to add them."
    hint = "(based on tracked recorded hours) #{hint}" if offered
    blocks << SlackBot::Blocks.input("Time spent (hours)", SlackBot::Blocks.plain_text_input("duration", placeholder: "Hours, like 1.5 or 0.5", initial_value: duration.presence || offered), block_id: "duration", hint: hint)
    blocks << SlackBot::Blocks.context("Nothing tracked since your last journal. Join the huddle or start the timer on your pet next time and the hours fill in.") if duration.nil? && !offered && tracked
    blocks += timelapse_blocks(draft)
    blocks << SlackBot::Blocks.context(":warning: #{escape(error)}") if error
    blocks << SlackBot::Blocks.actions(
      draft_button("Save journal", "journal", draft, style: "primary"),
      draft_button("Add more", "more", draft),
      draft_button("Not a journal", "skip", draft)
    )
    blocks << SlackBot::Blocks.context("#{draft_counts(draft)}. Anything else you post here joins it until you pick.")
    { text: "Is this a journal for #{draft.project.title}?", blocks: blocks }
  end

  TIMELAPSE_LABEL = "Timelapses (helps you not get deflated)"
  # The prompt's timelapse line. With Lapse connected: what is picked, and a button opening the picker modal. Without
  # it, a button that connects it on Fallen, after which the prompt redraws itself (RefreshDraftPromptJob). With
  # nothing to pick, where to record one and a button to look again. Never a box for a link: timelapses only ever
  # come from their own Lapse.
  def timelapse_blocks(draft)
    user = draft.user
    return [] unless Lapse.configured?

    unless user.lapse_connected?
      connect = draft_button("Connect Lapse", "connect_lapse", draft).merge(url: connect_lapse_url)
      return [ SlackBot::Blocks.section("*#{TIMELAPSE_LABEL}*\nConnect Lapse on Fallen to pick your timelapses here.", accessory: connect) ]
    end

    picked = draft.picked_timelapses
    if picked.empty? && !pickable_timelapses?(user)
      text = "*#{TIMELAPSE_LABEL}*\nNo unused timelapses on Lapse yet. <#{Lapse.web_host}|Record one>, then check again."
      return [ SlackBot::Blocks.section(text, accessory: draft_button("Check again", "check_lapse", draft)) ]
    end

    summary = picked.any? ? "#{picked.map { |timelapse| escape(timelapse_name(timelapse)) }.join(', ')} · #{Duration.format(picked.sum(&:duration_minutes))}" : "None picked yet."
    [ SlackBot::Blocks.section("*#{TIMELAPSE_LABEL}*\n#{summary}", accessory: draft_button(picked.any? ? "Change" : "Pick timelapses", "pick_lapse", draft)) ]
  end

  # A modal of all their timelapses, newest first, LapsePicker::PER_PAGE to a page (with dividers that is at most
  # 3 blocks each, inside Slack's 100 a modal): thumbnail, name and length,
  # and a checkbox for the ones that can back this journal. Ones another journal has, or Lapse can't play, say why
  # instead. Ticks are read when the page changes or on "Done" (LapsePickerAction, LapsePickerView).
  def lapse_picker(journal_draft, picker, error: nil)
    timelapses = journal_draft.user.lapse_timelapses.newest_first.includes(journal: :project)
    pages = [ (timelapses.count / LapsePicker::PER_PAGE.to_f).ceil, 1 ].max
    page = picker.page.clamp(0, pages - 1)
    shown = timelapses.offset(page * LapsePicker::PER_PAGE).limit(LapsePicker::PER_PAGE).to_a
    picker = picker.with(page: page, page_ids: shown.reject { |timelapse| timelapse_blocked(timelapse) }.map(&:public_id))

    blocks = [ SlackBot::Blocks.context("Powered by :lapse: Lapse, select sessions that you want to attach to this journal!") ]
    # No count of ticks: Slack doesn't redraw the modal on a tick, so it would go stale.
    blocks << SlackBot::Blocks.context("Page #{page + 1} of #{pages}") if pages > 1
    blocks << SlackBot::Blocks.context(":warning: #{escape(error)}") if error
    shown.each do |timelapse|
      reason = timelapse_blocked(timelapse)
      recorded = timelapse.recorded_at && " · #{timelapse.recorded_at.in_time_zone(journal_draft.user.timezone).to_date.to_fs(:long)}"
      detail = if timelapse.claimed_by
        "_On your <#{journal_url(timelapse.claimed_by)}|journal from #{timelapse.claimed_by.created_at.in_time_zone(journal_draft.user.timezone).to_date.to_fs(:long)}>_"
      elsif reason
        "_#{reason.delete_prefix('is ').capitalize}_"
      else
        "#{timelapse.duration_text}#{recorded}"
      end
      thumbnail = SlackBot::Blocks.image(timelapse.thumbnail_url, timelapse_name(timelapse)) if timelapse.thumbnail_url.present?
      blocks << SlackBot::Blocks.divider
      blocks << SlackBot::Blocks.section("*#{escape(timelapse_name(timelapse))}*\n#{detail}", accessory: thumbnail)
      next if reason

      option = SlackBot::Blocks.option("Use this one", timelapse.public_id)
      blocks << SlackBot::Blocks.actions(SlackBot::Blocks.checkboxes("lapse_picker:tick", [ option ], initial: (picker.selected.include?(timelapse.public_id) ? [ option ] : nil)),
                                         block_id: "#{LapsePicker::CHECKBOX_BLOCK}#{timelapse.public_id}")
    end
    pager = [ (SlackBot::Blocks.button("‹ Newer", "lapse_picker:page", value: (page - 1).to_s) if page.positive?),
              (SlackBot::Blocks.button("Older ›", "lapse_picker:page", value: (page + 1).to_s) if page < pages - 1) ].compact
    blocks += [ SlackBot::Blocks.divider, SlackBot::Blocks.actions(pager) ] if pager.any?
    SlackBot::Blocks.modal("Timelapses Selection", blocks, callback_id: "lapse_picker", submit: "Done", private_metadata: picker.to_json)
  end

  # Why a timelapse can't back a new journal, or nil.
  def timelapse_blocked(timelapse) = timelapse.claimed_by ? "is #{timelapse.claim_text}" : timelapse.unusable_reason

  def pickable_timelapses?(user) = user.lapse_timelapses.unclaimed.any?(&:usable?)

  def timelapse_name(timelapse) = (timelapse.name.presence || "Untitled timelapse").truncate(60)

  # A journal needs Journal::MIN_BODY_LENGTH characters of writing and a photo per Journal::MINUTES_PER_IMAGE of the
  # time tracked so far (at least one), so a draft short of either gets a reminder saying what is missing instead
  # of the time box. Anything they post next in the thread joins the draft.
  def needs_more_prompt(draft, tracked: nil)
    written = Journal.written_length(draft.text)
    short = written < Journal::MIN_BODY_LENGTH
    count = draft.files.empty? ? [ (tracked.to_i / Journal::MINUTES_PER_IMAGE.to_f).ceil, 1 ].max : 0
    photos = count == 1 ? "a photo" : "#{count} photos"
    writing = "at least #{Journal::MIN_BODY_LENGTH} characters so a reviewer can follow what you did (you're at #{written})"
    text = if short && count.positive?
      "Nice! Please write a bit more, #{writing}, and add #{photos} for your journal :>> you can just keep sending messages here!"
    elsif short
      "Nice! Please write a bit more about what you did, #{writing} :>> you can just send another message!"
    else
      "Nice! Please also add #{photos} for your journal :>> you can just send a message with the #{count == 1 ? 'photo' : 'photos'}!"
    end
    blocks = [ SlackBot::Blocks.section("#{text}\n#{quote(draft.text, 1500)}"), SlackBot::Blocks.actions(draft_button("Not a journal", "skip", draft)) ]
    { text: text.split(" :>>").first + ".", blocks: blocks }
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
  # answer (HuddlePromptJob), and in their DMs on joining. Someone coming back with a goal from earlier is asked
  # whether they are still on it. HuddleGoalAction re-renders it with `error` when the answer is incomplete.
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

  # Posted in the huddle's thread when someone in it finishes signing up for Fallen (HuddleWelcomeJob).
  def huddle_welcome(user)
    { text: "<@#{user.slack_id}> just joined Fallen!! say hi :wave:", **pet_persona(user.pet) }
  end

  def huddle_welcome_dm(user)
    text = "Welcome to Fallen! Your time in the huddle is on your account now."
    blocks = [ SlackBot::Blocks.section(text) ]
    blocks << SlackBot::Blocks.actions(SlackBot::Blocks.button("Start a project", "open_fallen", url: new_project_url, style: "primary")) unless user.projects.kept.exists?
    { text: text, blocks: blocks, **pet_persona(user.pet) }
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

  HUDDLE_DONE_INPUT = "done"
  HUDDLE_HOURS_INPUT = "hours"

  # In their DMs, from their pet, a little while after they leave the huddle (HuddleWrapUpJob): what they got done
  # and, for someone signed up, how many of the hours it counted were really work (HonestHours). There is no skip;
  # someone who never answers keeps all their time. HuddleDoneAction
  # re-renders it with `error` when the answer is empty or the hours do not add up.
  def huddle_wrap_up(session, error: nil)
    question = if session.mode == "working" && session.goal.present?
      "Thanks for hanging out! You were working on #{escape(session.goal)}. What did you get done?"
    else
      "Thanks for hanging out! What did you get done?"
    end
    blocks = [ SlackBot::Blocks.section(question),
               SlackBot::Blocks.input("I got done", SlackBot::Blocks.plain_text_input(HUDDLE_DONE_INPUT, multiline: true, max_length: 1000), block_id: HUDDLE_DONE_INPUT) ]
    if session.user && (counted = session.visit_seconds).positive?
      choices = HonestHours.choices(counted).map { |label, hours| SlackBot::Blocks.option(label, hours) }
      blocks << SlackBot::Blocks.input("Honestly, how many hours of that were you working?",
        SlackBot::Blocks.static_select(HUDDLE_HOURS_INPUT, choices, initial: choices.first), block_id: HUDDLE_HOURS_INPUT,
        hint: "The huddle counted #{HonestHours.text(counted)} hours.")
    end
    blocks << SlackBot::Blocks.context(":warning: #{escape(error)}") if error
    blocks << SlackBot::Blocks.actions(SlackBot::Blocks.button("save", "huddle_done:share", value: session.public_id, style: "primary"))
    { text: question, blocks: blocks, **pet_persona(session.user&.pet) }
  end

  def huddle_done_answer(session)
    text = session.done.present? ? ":tada: You got done: #{escape(session.done)}" : "No worries, see you next time!"
    { text: text, blocks: [ SlackBot::Blocks.section(text) ] }
  end

  # Posted in the huddle's thread, as their pet, once someone says what they got done (HuddleDoneJob).
  def huddle_done(session)
    { text: "<@#{session.slack_id}> got this done in the huddle: #{escape(session.done)} :tada:", **pet_persona(session.user&.pet) }
  end

  # Only they see it, from their pet, each TimeMilestone::EVERY since their last journal (TimeMilestoneJob).
  def time_milestone(user, minutes)
    { text: "#{duration_words(minutes)} since your last journal :tada: keep going!", **pet_persona(user.pet) }
  end

  # "30 minutes", "1 hour", "1.5 hours".
  def duration_words(minutes)
    return "#{minutes} minutes" if minutes < 60

    hours = (minutes / 60.0).round(1)
    hours = hours.to_i if hours == hours.to_i
    "#{hours} #{hours == 1 ? 'hour' : 'hours'}"
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

  # Uploads the editor embedded (relative links to the site, which Slack can't open) and Markdown images with no
  # web address. The editor drops an upload in at the cursor, which can land inside another image's Markdown, so the
  # uploads go first and the second match spans lines.
  def without_embedded_images(markdown)
    markdown.to_s.gsub(%r{!?\[[^\]\n]*\]\(/rails/active_storage/[^)\s]*\)}, "").gsub(%r{!\[[^\]]*\]\((?!https?://)[^)]*\)}, "")
  end

  def blob_url(image) = Rails.application.routes.url_helpers.rails_blob_url(image, host: ENV.fetch("APP_URL", "http://localhost:3000"))

  def project_url(project) = Rails.application.routes.url_helpers.project_url(project, host: ENV.fetch("APP_URL", "http://localhost:3000"))

  # A journal's own message in its project's thread, or failing that the journal on its project's page.
  def journal_url(journal) = journal.slack_url || Rails.application.routes.url_helpers.project_url(journal.project, host: app_url, anchor: "journal-#{journal.public_id}")

  def journal_url(journal) = Rails.application.routes.url_helpers.project_url(journal.project, anchor: "journal-#{journal.public_id}", host: ENV.fetch("APP_URL", "http://localhost:3000"))

  def hatch_url = Rails.application.routes.url_helpers.home_url(hatch: 1, host: ENV.fetch("APP_URL", "http://localhost:3000"))

  def new_project_url = Rails.application.routes.url_helpers.new_project_url(host: ENV.fetch("APP_URL", "http://localhost:3000"))

  def app_url = ENV.fetch("APP_URL", "http://localhost:3000")
  # Back to Settings' Lapse tab afterwards, where the notice says to head back to Slack.
  def connect_lapse_url = Rails.application.routes.url_helpers.connect_lapse_url(host: app_url, return_to: "/settings#lapse")

  def escape(text) = text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
end
