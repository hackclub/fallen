# "Select" on a timelapse in the Slack timelapse picker (SlackMessages.lapse_picker): toggles it and redraws the
# modal. The picks so far ride in the modal's private_metadata until "Done" (LapsePickerView).
class LapsePickerAction < SlackBot::Action
  def call
    picker = JSON.parse(payload.view&.private_metadata.presence || "{}")
    draft = JournalDraft.find_by_public_id(picker["draft"])
    return unless draft && user && draft.user_id == user.id

    selected = Array(picker["selected"])
    selected = selected.include?(value) ? selected - [ value ] : (selected + [ value ]).first(Journal::MAX_TIMELAPSES)
    update_modal(SlackMessages.lapse_picker(draft, selected, duration: picker["duration"]))
  end
end
