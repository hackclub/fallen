# The buttons on the "what did you get done?" DM (HuddleWrapUpJob, SlackMessages.huddle_wrap_up). action_id is
# "huddle_done:share" or "huddle_done:skip", the value the HuddleSession's public id. Sharing stores the answer and
# tells the huddle (HuddleDoneJob).
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

    session.update!(done: done.truncate(1000))
    reply(session)
    HuddleDoneJob.perform_later(session)
  end

  def reply(session)
    answer = SlackMessages.huddle_done_answer(session)
    update_message(answer[:text], blocks: answer[:blocks])
  end
end
