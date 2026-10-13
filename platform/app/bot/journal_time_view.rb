# The typed-duration modal opened by JournalTimeAction.
class JournalTimeView < SlackBot::View
  extend SlackBot::Blocks

  def self.build(journal, response_url: nil)
    modal(
      "How long did it take?",
      [ input("Time spent", plain_text_input("duration", placeholder: "1h 45m, 2.5, 50m…"), block_id: "duration", hint: "However you'd write it.") ],
      callback_id: "journal_time",
      submit: "Log it",
      private_metadata: { journal_id: journal.public_id, response_url: response_url }.compact.to_json
    )
  end

  def call
    metadata = JSON.parse(private_metadata.to_s) rescue {}
    journal = Journal.kept.find_by_public_id(metadata["journal_id"])
    return close unless journal && user && journal.user_id == user.id

    journal.duration = values["duration"]
    return errors(duration: journal.errors.full_messages.first) unless journal.save

    replace_prompt(metadata["response_url"], journal)
    close
  end

  private

  def replace_prompt(response_url, journal)
    return if response_url.blank?

    text = ":white_check_mark: *#{journal.duration_text}* logged on *#{SlackMessages.escape(journal.project.title)}*. <#{SlackMessages.project_url(journal.project)}|Open on Fallen>"
    Faraday.post(response_url, { replace_original: true, text: text, blocks: [ section(text) ] }.to_json, "Content-Type" => "application/json")
  rescue Faraday::Error
    nil
  end
end
