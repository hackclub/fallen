# The buttons on the huddle prompt (HuddlePromptJob, SlackMessages.huddle_prompt). action_id is
# "huddle_goal:commit" or "huddle_goal:chill"; on the "still working on it?" prompt, "huddle_goal:pick" is a choice
# being picked (the session is the block_id) and "huddle_goal:still" submits it (value "<session>:<pick>"). Otherwise
# the value is the HuddleSession's public id. The answer is stored on that session and on the one they have open
# now, in case they dropped out and back in before answering. The prompt is in the thread and their DMs; answering
# one updates the other's DM copy (HuddleDmAnswerJob). The thread copy is ephemeral and can't be updated, so someone
# may answer both; only the first commit is announced.
class HuddleGoalAction < SlackBot::Action
  def call
    session_id, @picked = (arg == "pick" ? action.block_id : value).to_s.split(":", 2)
    session = HuddleSession.find_by_public_id(session_id)
    return delete_message if session.nil?
    return unless session.slack_id == slack_user_id

    case arg
    when "commit" then commit(session, goal_typed)
    when "chill" then answer(session, mode: "chilling", goal: nil)
    when "pick" then ask_again(session, nil, picked: selected_option&.value)
    when "still" then still(session)
    end
  end

  private

  def still(session)
    case @picked
    when "yes" then answer(session, mode: "working", goal: session.goal)
    when "other" then commit(session, goal_typed)
    when "chill" then answer(session, mode: "chilling", goal: nil)
    else ask_again(session, "Pick one!")
    end
  end

  def commit(session, goal)
    return ask_again(session, "Write what you're working on first!") if goal.blank?

    announced = session.mode == "working"
    answer(session, mode: "working", goal: goal.truncate(500))
    HuddleCommitJob.perform_later(session) unless announced
  end

  def answer(session, mode:, goal:)
    rows = session.huddle.sessions.where(slack_id: session.slack_id).merge(HuddleSession.ongoing.or(HuddleSession.where(id: session.id))).to_a
    rows.each { |row| row.update!(mode: mode, goal: goal) }
    reply = SlackMessages.huddle_answer(session.reload)
    update_message(reply[:text], blocks: reply[:blocks])
    rows.each { |row| HuddleDmAnswerJob.perform_later(row) if row.prompt_dm_ts && row.dm_channel_id != channel_id }
  end

  def ask_again(session, error, picked: @picked)
    prompt = SlackMessages.huddle_prompt(session, picked: picked, error: error)
    update_message(prompt[:text], blocks: prompt[:blocks])
  end

  def goal_typed = input_values[SlackMessages::HUDDLE_GOAL_INPUT].to_s.squish
end
