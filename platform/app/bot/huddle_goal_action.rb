# The buttons on the huddle prompt (HuddlePromptJob, SlackMessages.huddle_prompt). action_id is
# "huddle_goal:commit" or "huddle_goal:chill", the value is the HuddleSession's public id. The answer is stored on
# every session the person has in that huddle, so it carries over if they drop out and back in.
class HuddleGoalAction < SlackBot::Action
  def call
    session = HuddleSession.find_by_public_id(value)
    return delete_message if session.nil?
    return unless session.slack_id == slack_user_id

    case arg
    when "commit" then commit(session)
    when "chill" then answer(session, mode: "chilling", goal: nil)
    end
  end

  private

  def commit(session)
    goal = input_values["goal"].to_s.squish
    if goal.blank?
      prompt = SlackMessages.huddle_prompt(session, error: "Write what you're working on first!")
      return update_message(prompt[:text], blocks: prompt[:blocks])
    end

    answer(session, mode: "working", goal: goal.truncate(500))
  end

  def answer(session, mode:, goal:)
    session.huddle.sessions.where(slack_id: session.slack_id).update_all(mode: mode, goal: goal, updated_at: Time.current)
    reply = SlackMessages.huddle_answer(session.reload)
    update_message(reply[:text], blocks: reply[:blocks])
  end
end
