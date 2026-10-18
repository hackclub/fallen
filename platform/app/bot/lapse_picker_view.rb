# "Done" on the Slack timelapse picker: keeps the picks on the journal draft and redraws its prompt to show them
# (RefreshDraftPromptJob), keeping what was in the time box.
class LapsePickerView < SlackBot::View
  def call
    picker = JSON.parse(private_metadata.presence || "{}")
    draft = JournalDraft.find_by_public_id(picker["draft"])
    return close unless draft && user && draft.user_id == user.id

    draft.update!(timelapse_ids: user.lapse_timelapses.where_public_ids(Array(picker["selected"])).map(&:public_id))
    RefreshDraftPromptJob.perform_later(draft, picker["duration"])
    close
  end
end
