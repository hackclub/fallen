# "Done" on the Slack timelapse picker: keeps the ticked timelapses on the journal draft and redraws its prompt to
# show them (RefreshDraftPromptJob), keeping what was in the time box.
class LapsePickerView < SlackBot::View
  def call
    picker = LapsePicker.from(view).with_ticks(view)
    draft = picker.journal_draft
    return close unless draft && user && draft.user_id == user.id
    if picker.selected.size > Journal::MAX_TIMELAPSES
      return update_view(SlackMessages.lapse_picker(draft, picker, error: "That's #{picker.selected.size} ticked. A journal takes up to #{Journal::MAX_TIMELAPSES}."))
    end

    draft.update!(timelapse_ids: user.lapse_timelapses.where_public_ids(picker.selected).map(&:public_id))
    RefreshDraftPromptJob.perform_later(draft, picker.duration)
    close
  end
end
