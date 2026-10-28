# Copies a transferred journal's photos from the program it came from onto the journal (ProjectTransfer#approve),
# so they show like any other journal's, and takes their links out of the writing. Only from those programs' own
# photo hosts; a photo that can't be copied, or one past Journal::MAX_IMAGES, stays a link. A run cut short starts
# over, and photos already copied are skipped by their link. A photo host can redirect to where it keeps the file,
# so a few redirects are followed, over HTTPS only.
class CopyTransferPhotosJob < ApplicationJob
  queue_as :background
  limits_concurrency key: ->(journal) { journal }, duration: 5.minutes, on_conflict: :discard

  HOSTS = %w[stardance.hackclub.com fabricate.hackclub-assets.com cdn.hackclub.com fallout.hackclub.com].freeze
  REDIRECTS = 3

  def perform(journal)
    return unless journal.transferred? && journal.kept?

    copied = journal.images.blobs.filter_map { |blob| blob.metadata["source_url"] }
    journal.body.scan(ProjectTransfer::PHOTO_LINK).flatten.each do |url|
      copied << url if !copied.include?(url) && journal.images.count < Journal::MAX_IMAGES && attach(journal, url)
    end

    journal.reload
    body = journal.body.lines.reject { |line| line.strip.match(ProjectTransfer::PHOTO_LINK)&.then { copied.include?(it[1]) } }.join
    journal.update!(body: body.gsub(/\n{3,}/, "\n\n")) if body != journal.body
  end

  private

  def attach(journal, url)
    return false unless allowed_host?(url)

    response = download(url)
    return false unless response.success? && response.body.bytesize <= Journal::MAX_IMAGE_BYTES

    # The type comes from the bytes, as for uploads on the site (UploadsController).
    content_type = Marcel::MimeType.for(StringIO.new(response.body))
    return false unless content_type.in?(Journal::IMAGE_TYPES)

    filename = File.basename(CGI.unescape(URI.parse(url).path)).presence || "photo"
    journal.images.attach(io: StringIO.new(response.body), filename:, content_type:, identify: false,
                          metadata: { Journal::UPLOADER_KEY => journal.user_id, "source_url" => url })
  rescue Faraday::Error, URI::Error, ActiveRecord::RecordInvalid
    false
  end

  def download(url, redirects: REDIRECTS)
    response = Faraday.get(url) do |request|
      request.options.open_timeout = 5
      request.options.timeout = 20
    end
    location = response.headers["location"]
    return response unless response.status.in?(300..399) && location.present? && redirects.positive?

    target = URI.join(url, location)
    target.is_a?(URI::HTTPS) ? download(target.to_s, redirects: redirects - 1) : response
  end

  def allowed_host?(url)
    uri = URI.parse(url)
    uri.is_a?(URI::HTTPS) && uri.host.to_s.downcase.in?(HOSTS)
  rescue URI::InvalidURIError
    false
  end
end
