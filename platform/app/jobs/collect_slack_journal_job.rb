# Finishes a journal made from Slack replies (JournalDraftAction): copies their photos onto it.
class CollectSlackJournalJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  # The third argument was the replies to react to; jobs queued before that stopped still pass it.
  # A run cut short by a deploy starts over, so photos it already copied are skipped by their Slack file id.
  def perform(journal, files, _message_ts = nil)
    copied = journal.images.blobs.filter_map { |blob| blob.metadata["slack_file_id"] }
    room = Journal::MAX_IMAGES - journal.images.count
    files.reject { |file| copied.include?(file["id"]) }.first([ room, 0 ].max).each { |file| attach(journal, file) }
  end

  private

  def attach(journal, file)
    return if file["size"].to_i > Journal::MAX_IMAGE_BYTES

    url = file["url"].presence || SlackBot.client.files_info(file: file["id"]).file.url_private_download
    # The URL comes from the event, and the request carries the bot token: only ever send it to Slack.
    return unless slack_host?(url)

    response = Faraday.get(url, nil, "Authorization" => "Bearer #{ENV.fetch('SLACK_BOT_TOKEN')}")
    # Without files:read Slack answers with its sign-in page instead of the file.
    return unless response.success? && response.headers["content-type"].to_s.start_with?("image/") && response.body.bytesize <= Journal::MAX_IMAGE_BYTES

    # The type comes from the bytes, as for uploads on the site (UploadsController).
    content_type = Marcel::MimeType.for(StringIO.new(response.body))
    return unless content_type.in?(Journal::IMAGE_TYPES)

    journal.images.attach(io: StringIO.new(response.body), filename: file["name"].presence || "photo", content_type:, identify: false, metadata: { slack_file_id: file["id"] })
  rescue Faraday::Error, Slack::Web::Api::Errors::FileNotFound
    nil
  end

  def slack_host?(url)
    uri = URI.parse(url.to_s)
    uri.is_a?(URI::HTTPS) && uri.host.to_s.downcase.end_with?(".slack.com")
  rescue URI::InvalidURIError
    false
  end
end
