# Where someone is in the Slack timelapse picker (SlackMessages.lapse_picker), carried in the modal's
# private_metadata: their draft, every timelapse ticked so far on any page, the page shown and its timelapses, and
# what was in the prompt's time box. Ticks live in Slack's own state for the page on screen; `with_ticks` folds
# them in whenever the page changes or the picker is done.
class LapsePicker < Data.define(:draft, :selected, :page, :page_ids, :duration)
  PER_PAGE = 20
  CHECKBOX_BLOCK = "lapse_pick_"

  def self.start(draft, duration:) = new(draft: draft.public_id, selected: draft.timelapse_ids, page: 0, page_ids: [], duration: duration)

  def self.from(view)
    picker = JSON.parse(view&.to_h&.dig("private_metadata").presence || "{}")
    new(draft: picker["draft"], selected: Array(picker["selected"]), page: picker["page"].to_i, page_ids: Array(picker["page_ids"]), duration: picker["duration"])
  end

  # Slack's state for the page on screen: ticked boxes added, unticked ones on this page dropped.
  def with_ticks(view)
    values = view&.to_h&.dig("state", "values") || {}
    ticked = page_ids.select { |id| values["#{CHECKBOX_BLOCK}#{id}"]&.values&.first&.dig("selected_options").present? }
    with(selected: (selected - page_ids + ticked).uniq)
  end

  def journal_draft = JournalDraft.find_by_public_id(draft)

  def to_json(*) = { draft: draft, selected: selected, page: page, page_ids: page_ids, duration: duration }.to_json
end
