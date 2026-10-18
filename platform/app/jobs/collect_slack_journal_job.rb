# Finishes a journal made from Slack replies (JournalDraftAction): copies their photos onto it.
class CollectSlackJournalJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  # The third argument was the replies to react to; jobs queued before that stopped still pass it.
  def perform(journal, files, _message_ts = nil)
    room = Journal::MAX_IMAGES - journal.images.count
    files.first([ room, 0 ].max).each { |file| attach(journal, file) }
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
