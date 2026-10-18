# Inside the Slack timelapse picker (SlackMessages.lapse_picker). Ticking a box needs nothing: Slack keeps it until
# the page changes or "Done" (LapsePickerView). "Newer" and "Older" fold this page's ticks in and show the next page.
class LapsePickerAction < SlackBot::Action
  def call
    return unless arg == "page"

    picker = LapsePicker.from(payload.view).with_ticks(payload.view)
    draft = picker.journal_draft
    return unless draft && user && draft.user_id == user.id

    update_modal(SlackMessages.lapse_picker(draft, picker.with(page: value.to_i)))
  end
end
