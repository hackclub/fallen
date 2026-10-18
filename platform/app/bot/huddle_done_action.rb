# The save button on the "what did you get done?" DM (HuddleWrapUpJob, SlackMessages.huddle_wrap_up). action_id is
# "huddle_done:share" ("huddle_done:skip" on DMs sent before skipping was taken out), the value the HuddleSession's
# public id. Sharing stores the answer and
# any hours they say were not really work (HonestHours, `deducted_seconds`), and tells the huddle (HuddleDoneJob).
class HuddleDoneAction < SlackBot::Action
  def call
    session = HuddleSession.find_by_public_id(value)
    return delete_message if session.nil?
    return unless session.slack_id == slack_user_id

    case arg
    when "share" then share(session)
    when "skip" then reply(session)
    end
  end

  private

  def share(session)
    done = input_values[SlackMessages::HUDDLE_DONE_INPUT].to_s.strip
    if done.blank?
      prompt = SlackMessages.huddle_wrap_up(session, error: "Write what you got done first!")
      return update_message(prompt[:text], blocks: prompt[:blocks])
    end

    counted = session.visit_seconds
    deducted = HonestHours.deduction(input_values[SlackMessages::HUDDLE_HOURS_INPUT], counted)
    if deducted.nil?
      prompt = SlackMessages.huddle_wrap_up(session, error: "Pick how many hours you were working")
      return update_message(prompt[:text], blocks: prompt[:blocks])
    end

    session.transaction do
      session.update!(done: done.truncate(1000))
      session.deduct_from_visit!(deducted)
    end
    reply(session)
    HuddleDoneJob.perform_later(session)
  end

  def reply(session)
    answer = SlackMessages.huddle_done_answer(session)
    update_message(answer[:text], blocks: answer[:blocks])
  end
end
