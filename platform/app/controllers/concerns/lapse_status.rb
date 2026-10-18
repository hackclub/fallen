# frozen_string_literal: true

# What the journal composer and settings need to know about the person's Lapse connection.
module LapseStatus
  extend ActiveSupport::Concern

  private

  def lapse_props(timelapses: false)
    props = { configured: Lapse.configured?, connected: current_user.lapse_connected?, synced_at: current_user.lapse_synced_at }
    return props unless timelapses

    # All of them, newest first: the ones already on a journal show greyed out, so none seem to go missing.
    timelapses = current_user.lapse_timelapses.newest_first.includes(journal: :project)
    props.merge(timelapses: LapseTimelapseSerializer.render(timelapses, claims: true))
  end
end
