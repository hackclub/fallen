# The buttons on the huddle prompt (HuddlePromptJob, SlackMessages.huddle_prompt). action_id is
# "huddle_goal:commit", "huddle_goal:chill" or, on the "still working on it?" prompt, "huddle_goal:still"; the value
# is the HuddleSession's public id. The answer is stored on that session and on the one they have open now, in case
# they dropped out and back in before answering.
class HuddleGoalAction < SlackBot::Action
  def call
    session = HuddleSession.find_by_public_id(value)
    return delete_message if session.nil?
    return unless session.slack_id == slack_user_id

    case arg
    when "commit" then commit(session, goal_typed)
    when "chill" then answer(session, mode: "chilling", goal: nil)
    when "still" then still(session)
    end
  end

  private

  def still(session)
    case input_values[SlackMessages::HUDDLE_STILL_INPUT]
    when "yes" then answer(session, mode: "working", goal: session.goal)
    when "other" then commit(session, goal_typed)
    when "chill" then answer(session, mode: "chilling", goal: nil)
    else ask_again(session, "Pick one!")
    end
  end

  def commit(session, goal)
    return ask_again(session, "Write what you're working on first!") if goal.blank?

    answer(session, mode: "working", goal: goal.truncate(500))
    HuddleCommitJob.perform_later(session)
  end

  def answer(session, mode:, goal:)
    session.huddle.sessions.where(slack_id: session.slack_id).merge(HuddleSession.ongoing.or(HuddleSession.where(id: session.id)))
           .update_all(mode: mode, goal: goal, updated_at: Time.current)
    reply = SlackMessages.huddle_answer(session.reload)
    update_message(reply[:text], blocks: reply[:blocks])
  end

  def ask_again(session, error)
    prompt = SlackMessages.huddle_prompt(session, error: error)
    update_message(prompt[:text], blocks: prompt[:blocks])
  end

  def goal_typed = input_values[SlackMessages::HUDDLE_GOAL_INPUT].to_s.squish
end
