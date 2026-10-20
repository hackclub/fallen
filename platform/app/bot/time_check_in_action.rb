# The buttons on the hourly check-in DM (TimeMilestoneJob, SlackMessages.time_check_in). action_id is
# "time_check_in:save" or "time_check_in:stop", the value the TimeMilestone's public id. Save stores what they got
# done so far; Stop does what Pause on the pet does: stops the site timer, and stops counting in the huddle
# without taking them out of it (HuddlePause).
class TimeCheckInAction < SlackBot::Action
  def call
    check_in = TimeMilestone.find_by_public_id(value)
    return delete_message if check_in.nil?
    return unless user && check_in.user_id == user.id

    case arg
    when "save" then save(check_in)
    when "stop" then stop(check_in)
    end
  end

  private

  def save(check_in)
    return redraw(check_in, error: "Write what you've gotten done first!") unless check_in.answered? || check_in.answer!(input_values[SlackMessages::TIME_CHECK_IN_INPUT])

    redraw(check_in)
  end

  # Anything typed in the box before pressing Stop is kept as the answer.
  def stop(check_in)
    typed = input_values[SlackMessages::TIME_CHECK_IN_INPUT]
    check_in.answer!(typed) if typed.present? && !check_in.answered?
    TimerSession.stop(user)
    HuddlePause.start(user)
    redraw(check_in)
  end

  def redraw(check_in, error: nil)
    message = SlackMessages.time_check_in(check_in, TrackedTime.new(user).running, error: error)
    update_message(message[:text], blocks: message[:blocks])
  end
end
