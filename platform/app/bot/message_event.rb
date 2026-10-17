# Watches the journals channel. Replies in a project's thread by its owner are collected into a JournalDraft and
# become a journal only when they say so (JournalPromptJob asks once they pause), since they may just be chatting.
# Replies by anyone else are conversation and left alone. Top-level messages are only written by Fallen (project
# anchors, PostProjectToSlackJob); anything else is removed by RemoveStrayPostJob. Edits and deletions in Slack flow
# back to the draft or journal.
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
      collect_reply
    elsif channel_id == SlackMessaging.journals_channel_id
      remove_stray_post
    end
  end

  def in_thread? = event.thread_ts.present? && event.thread_ts != ts

  def collect_reply
    project = Project.find_by_slack_thread(channel_id, event.thread_ts) or return
    return unless user && project.user_id == user.id
    return if Journal.find_by_slack_message(channel_id, ts)
    return if echo_of_web_journal?(project)
    return if text.strip.empty? && photos.empty?

    draft = JournalDraft.collect(project, user, ts: ts, text: text, files: photos)
    # A first reply is asked about straight away; later ones wait in case more are coming.
    prompt = draft.message_count == 1 ? JournalPromptJob : JournalPromptJob.set(wait: JournalDraft::ASK_AFTER)
    prompt.perform_later(draft, ts)
  end

  def photos
    @photos ||= Array(event.files).select { |file| file.mimetype.in?(Journal::IMAGE_TYPES) }.map do |file|
      { "id" => file.id, "name" => file.name, "mimetype" => file.mimetype, "url" => file.url_private_download, "size" => file.size }
    end
  end

  # A journal written on the web and posted as the person arrives here too. The job records its ts
  # right after posting, but the event can beat it; a same-text journal that is still unsent is the echo.
  def echo_of_web_journal?(project)
    project.journals.kept.where(user: user, slack_ts: nil, body: text).where(created_at: 10.minutes.ago..).exists?
  end

  # Project anchors are posted as the person but carry Fallen's bot_id, so from_bot? has already let them through.
  def remove_stray_post
    RemoveStrayPostJob.perform_later(channel_id, ts, slack_user_id, text)
  end

  def message_changed
    changed = event.message or return
    if (journal = Journal.find_by_slack_message(channel_id, changed.ts))
      journal.slack_message_edited(changed.ts, changed.text.to_s) unless journal.discarded?
    else
      JournalDraft.containing(changed.ts).first&.edit(changed.ts, changed.text.to_s)
    end
  end

  def message_deleted
    if (journal = Journal.find_by_slack_message(channel_id, event.deleted_ts))
      journal.slack_message_deleted(event.deleted_ts) unless journal.discarded?
    else
      JournalDraft.containing(event.deleted_ts).first&.remove(event.deleted_ts)
    end
  end
end
