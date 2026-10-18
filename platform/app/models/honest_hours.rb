# "How much of that was really work?", asked when a site timer stops (TimerSession#wrap_up!) and in the huddle's
# wrap-up DM (HuddleDoneAction). The answer is decimal hours, at most what was counted; the rest comes off the
# time on the pet (`deducted_seconds`, TrackedTime) and so off the hours a journal is checked against.
module HonestHours
  # The counted time is shown rounded to a hundredth of an hour, so an answer may be over it by that much.
  ROUNDING = 36.seconds
  # Slack has no slider, so the huddle DM offers a dropdown: all of it, then down in steps of this to none.
  STEP = 15.minutes
  # Slack's most options in a dropdown.
  MAX_CHOICES = 100

  module_function

  # Seconds to take off `counted` for someone who says `answer` hours of it were work. Blank takes nothing off.
  # Nil when the answer is not a number of hours or is more than was counted.
  def deduction(answer, counted)
    return 0 if answer.blank?

    minutes = Duration.parse(answer, allow_zero: true) or return
    claimed = minutes * 60
    return if claimed > counted + ROUNDING

    [ counted - claimed, 0 ].max
  end

  # The dropdown's choices as [label, hours], all of `counted` first.
  def choices(counted)
    step = [ STEP.to_i, (counted / (MAX_CHOICES - 1.0)).ceil ].max
    [ counted, *((counted - 1) / step).downto(0).map { |n| n * step } ].map { |seconds| [ "#{text(seconds)} hours", text(seconds) ] }
  end

  # "2.5", the way the question shows the counted time.
  def text(seconds) = Duration.format(seconds / 60).delete_suffix("h")
end
