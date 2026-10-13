# Watches the journals channel. A reply in a project's thread by its owner is a journal; a fresh top-level
# message gets a nudge to become a project. Edits and deletions in Slack flow back to the journal.
class MessageEvent < SlackBot::Event
  subscribes_to "message.channels", "message.groups"

  SAVED_EMOJI = "notebook_with_decorative_cover"

  def call
    case subtype
    when nil, "file_share", "thread_broadcast" then message_posted
    when "message_changed" then message_changed
    when "message_deleted" then message_deleted
    end
  end

  private

  def message_posted
    return if from_bot?

    if in_thread?
      journal_from_reply
    elsif channel_id == SlackMessaging.journals_channel_id
      nudge_new_project
    end
  end

  def in_thread? = event.thread_ts.present? && event.thread_ts != ts

  def journal_from_reply
    project = Project.find_by_slack_thread(channel_id, event.thread_ts) or return
    return unless user && project.user_id == user.id
    return if Journal.find_by_slack_message(channel_id, ts)
    return if echo_of_web_journal?(project)

    journal = project.journals.create!(user: user, body: text, source: "slack", slack_channel_id: channel_id, slack_ts: ts)
    SlackBot::Reactions.add(channel_id, ts, SAVED_EMOJI)
    ephemeral(nil, thread_ts: thread_ts, blocks: [
      section(":notebook_with_decorative_cover: Saved to *#{SlackMessages.escape(project.title)}*. How long did this session take?"),
      actions(button("Log time", "journal_time:#{journal.public_id}", style: "primary"), button("Skip", "dismiss_nudge"))
    ])
  end

  # A journal written on the web and posted as the person arrives here too. The job records its ts
  # right after posting, but the event can beat it; a same-text journal that is still unsent is the echo.
  def echo_of_web_journal?(project)
    project.journals.kept.where(user: user, slack_ts: nil, body: text).where(created_at: 10.minutes.ago..).exists?
  end

  def nudge_new_project
    if user.nil?
      ephemeral(":wave: Want this tracked as a project? Sign in at #{ENV.fetch('APP_URL', 'http://localhost:3000')} and run `/project`.")
      return
    end

    ephemeral(nil, blocks: [
      section(":hammer_and_wrench: Starting something new? Make this message your project thread and every reply you post in it becomes a journal."),
      actions(button("Make it a project", "project_from_message", value: ts, style: "primary"), button("No thanks", "dismiss_nudge"))
    ])
  end

  def message_changed
    changed = event.message or return
    journal = Journal.find_by_slack_message(channel_id, changed.ts) or return
    return if journal.discarded? || changed.text.to_s == journal.body

    journal.update(body: changed.text.to_s)
  end

  def message_deleted
    journal = Journal.find_by_slack_message(channel_id, event.deleted_ts) or return

    journal.discard
  end
end
