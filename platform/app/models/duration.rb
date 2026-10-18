# frozen_string_literal: true

# Time is typed and shown as decimal hours, like a digital clock readout: "1.5", "0.5", "0.1".
module Duration
  module_function

  def format(minutes)
    return nil if minutes.nil?

    hours = (minutes / 60.0).round(2)
    "#{hours == hours.to_i ? hours.to_i : hours}h"
  end

  def parse(text)
    m = text.to_s.strip.downcase.match(/\A(\d*\.?\d+)\s*h?\z/)
    return nil unless m

    minutes = (m[1].to_f * 60).round
    minutes.positive? ? minutes : nil
  end
end
