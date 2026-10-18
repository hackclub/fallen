# frozen_string_literal: true

# What the journal composer and settings need to know about the person's Lapse connection.
module LapseStatus
  extend ActiveSupport::Concern

  private

  def lapse_props(timelapses: false)
    props = { configured: Lapse.configured?, connected: current_user.lapse_connected?, synced_at: current_user.lapse_synced_at }
    return props unless timelapses

    unclaimed = current_user.lapse_timelapses.unclaimed.newest_first.limit(LapseTimelapse::LISTED)
    props.merge(timelapses: LapseTimelapseSerializer.render(unclaimed))
  end
end
