# The buttons on a draft prompt (JournalPromptJob, SlackMessages.draft_prompt). action_id is
# "journal_draft:<choice>", the value is the draft's public id. "Save journal" reads the time typed into the message.
# "Not a journal" on several messages shows SlackMessages.draft_picker instead, whose "Done" value also carries the
# newest message it listed. "Connect Lapse" (a link to Fallen), "Check again" and "Pick timelapses" (a modal,
# LapsePickerAction and LapsePickerView) remember where the prompt is, so it can be redrawn (RefreshDraftPromptJob).
class JournalDraftAction < SlackBot::Action
  def call
    draft_id, @upto = value.to_s.split(":", 2)
    draft = JournalDraft.find_by_public_id(draft_id)
    return update_message("Already sorted. Post again in the thread to start a new one.") if draft.nil? || draft.project.discarded?
    return unless user && draft.user_id == user.id

    case arg
    when "journal" then save_journal(draft)
    when "more" then keep_going(draft)
    when "attach" then attach_to_previous(draft)
    when "skip" then skip(draft)
    when "pick" then pick(draft)
    when "back" then show_prompt(draft)
    when "connect_lapse" then draft.remember_prompt!(response_url)
    when "check_lapse" then check_lapse(draft)
    when "pick_lapse" then pick_lapse(draft)
    end
  end

  private

  def save_journal(draft)
    files = draft.files
    # An older prompt may still carry a box for a Lapse link; it is ignored. Timelapses are only ever picked.
    duration = input_values["duration"]
    egg = !user.hatched?
    journal = draft.journal!(duration: duration, timelapses: draft.picked_timelapses)
    unless journal.persisted?
      prompt = SlackMessages.draft_prompt(draft, duration: duration.to_s, error: journal.errors.full_messages.first)
      return update_message(prompt[:text], blocks: prompt[:blocks])
    end

    CollectSlackJournalJob.perform_later(journal, files, journal.slack_parts.pluck("ts"))
    AddJournalFooterJob.perform_later(journal)
    if egg && user.reload.hatched?
      EggCrackingJob.perform_later(user)
      EggCrackingJob.perform_later(user, journal.project)
    end
    update_message(":white_check_mark: Journaled *#{journal.duration_text}* on *#{SlackMessages.escape(journal.project.title)}*. <#{SlackMessages.project_url(journal.project)}|Open on Fallen>")
  end

  def keep_going(draft)
    text = if draft.written?
      ":writing_hand: Keep going. Everything you post in this thread joins this journal, and I'll ask again when you pause."
    else
      ":frame_with_picture: Saved for your next journal. Write about it here when you're ready."
    end
    update_message(text)
  end

  def attach_to_previous(draft)
    journal = draft.previous_journal or return update_message("You don't have a journal on this project yet.")

    CollectSlackJournalJob.perform_later(journal, draft.files, draft.parts.pluck("ts"))
    draft.destroy!
    update_message(":white_check_mark: Added to your last journal on *#{SlackMessages.escape(draft.project.title)}*. <#{SlackMessages.project_url(draft.project)}|Open on Fallen>")
  end

  def skip(draft)
    if draft.message_count > 1
      prompt = SlackMessages.draft_picker(draft)
      return update_message(prompt[:text], blocks: prompt[:blocks])
    end

    draft.destroy!
    delete_message
  end

  def pick(draft)
    kept = input_values.select { |key, _| key.start_with?(SlackMessages::PICKER_INPUT) }.values.flatten.compact
    draft.keep_only(kept, upto: @upto)
    draft.destroyed? ? delete_message : show_prompt(draft)
  end

  # The picker opens straight away, from what Fallen already has; the prompt is redrawn when it is closed with Done.
  def pick_lapse(draft)
    draft.remember_prompt!(response_url)
    open_modal(SlackMessages.lapse_picker(draft, LapsePicker.start(draft, duration: input_values["duration"])))
  end

  # Asking Lapse takes a moment, so the prompt is redrawn from a job, keeping what is in the time box.
  def check_lapse(draft)
    draft.remember_prompt!(response_url)
    RefreshDraftPromptJob.perform_later(draft, input_values["duration"])
  end

  def show_prompt(draft)
    prompt = SlackMessages.draft_prompt(draft, tracked: TrackedTime.new(user).seconds / 60)
    update_message(prompt[:text], blocks: prompt[:blocks])
  end
end
