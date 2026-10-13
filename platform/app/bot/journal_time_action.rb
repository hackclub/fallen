# "Log time" under a journal saved from Slack (MessageEvent). action_id is "journal_time:<journal id>".
class JournalTimeAction < SlackBot::Action
  def call
    journal = Journal.kept.find_by_public_id(arg)
    return update_message("That journal is gone.") unless journal
    return update_message("Only the author can log time on this journal.") unless user && journal.user_id == user.id

    open_modal JournalTimeView.build(journal, response_url: response_url)
  end
end
