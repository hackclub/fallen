# frozen_string_literal: true

# Time is typed and shown as decimal hours, like a digital clock readout: "1.5", "0.5", "0.1".
module Duration
  module_function

  def format(minutes)
    return nil if minutes.nil?

    hours = (minutes / 60.0).round(2)
    "#{hours == hours.to_i ? hours.to_i : hours}h"
  end

  # Nil for anything that is not hours, and for no time at all unless `allow_zero`.
  def parse(text, allow_zero: false)
    m = text.to_s.strip.downcase.match(/\A(\d*\.?\d+)\s*h?\z/)
    return nil unless m

    minutes = (m[1].to_f * 60).round
    minutes.positive? || allow_zero ? minutes : nil
  end
end
