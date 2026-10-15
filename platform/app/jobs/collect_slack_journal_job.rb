# Finishes a journal made from Slack replies (JournalDraftAction): copies their photos onto it
# and marks each reply as saved.
class CollectSlackJournalJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(journal, files, message_ts)
    room = Journal::MAX_IMAGES - journal.images.count
    files.first([ room, 0 ].max).each { |file| attach(journal, file) }
    message_ts.each { |ts| SlackBot::Reactions.add(journal.project.slack_channel_id, ts, MessageEvent::SAVED_EMOJI) }
  end

  private

  def attach(journal, file)
    return if file["size"].to_i > Journal::MAX_IMAGE_BYTES

    url = file["url"].presence || SlackBot.client.files_info(file: file["id"]).file.url_private_download
    response = Faraday.get(url, nil, "Authorization" => "Bearer #{ENV.fetch('SLACK_BOT_TOKEN')}")
    # Without files:read Slack answers with its sign-in page instead of the file.
    return unless response.success? && response.headers["content-type"].to_s.start_with?("image/") && response.body.bytesize <= Journal::MAX_IMAGE_BYTES

    journal.images.attach(io: StringIO.new(response.body), filename: file["name"].presence || "photo", content_type: file["mimetype"])
  rescue Faraday::Error, Slack::Web::Api::Errors::FileNotFound
    nil
  end
end
