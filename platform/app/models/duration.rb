# frozen_string_literal: true

# Minutes in, human text out, and back again. Accepts "1.5", "1h30m", "90m", "2 hours", "45 min".
module Duration
  module_function

  def format(minutes)
    return nil if minutes.nil?

    hours, mins = minutes.divmod(60)
    parts = []
    parts << "#{hours}h" if hours.positive?
    parts << "#{mins}m" if mins.positive? || parts.empty?
    parts.join(" ")
  end

  def parse(text)
    text = text.to_s.strip.downcase
    return nil if text.blank?

    if (m = text.match(/\A(\d+(?:\.\d+)?)\s*(h|hr|hrs|hour|hours)?\z/))
      return (m[1].to_f * 60).round
    end

    hours = text[/(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)/, 1].to_f
    mins = (text[/(\d+)\s*(?:m|min|mins|minute|minutes)\b/, 1] || text[/(?:h|hr|hrs|hour|hours)\s*(\d+)\z/, 1]).to_i
    return nil if hours.zero? && mins.zero?

    (hours * 60).round + mins
  end
end
