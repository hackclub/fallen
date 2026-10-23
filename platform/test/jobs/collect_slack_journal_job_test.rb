require "test_helper"

class CollectSlackJournalJobTest < ActiveJob::TestCase
  PHOTOS = %w[F1 F2].map { |id| { "id" => id, "name" => "#{id}.png", "mimetype" => "image/png", "url" => "https://files.slack.com/files-pri/T1-#{id}/#{id}.png", "size" => 3 } }

  test "downloads photos from Slack and skips any other host, so the bot token only goes to Slack" do
    journal = journals(:first)
    files = [ "https://files.slack.com/files-pri/T1-F1/photo.png", "https://evil.test/photo.png", "https://files.slack.com.evil.test/photo.png",
              "https://files.slack.com@evil.test/photo.png", "http://files.slack.com/photo.png" ].map { |url| { "url" => url, "name" => "photo.png", "mimetype" => "image/png" } }

    with_env("SLACK_BOT_TOKEN" => "xoxb-test") do
      requested = with_fake_download { CollectSlackJournalJob.perform_now(journal, files) }
      assert_equal [ "https://files.slack.com/files-pri/T1-F1/photo.png" ], requested
    end
    assert_equal 1, journal.images.count
  end

  test "running again after being cut short copies only the photos it had not got to" do
    journal = journals(:first)

    with_env("SLACK_BOT_TOKEN" => "xoxb-test") do
      requested = with_fake_download do
        CollectSlackJournalJob.perform_now(journal, PHOTOS.first(1))
        CollectSlackJournalJob.perform_now(journal.reload, PHOTOS)
      end
      assert_equal PHOTOS.map { |photo| photo["url"] }, requested
    end

    assert_equal %w[F1.png F2.png], journal.reload.images.map { |image| image.filename.to_s }.sort
  end

  private

  def with_fake_download
    requested = []
    png = file_fixture("pixel.png").binread
    original_get = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |url, *_rest|
      requested << url
      Faraday::Response.new(status: 200, body: png, response_headers: { "content-type" => "image/png" })
    end
    yield
    requested
  ensure
    Faraday.define_singleton_method(:get, original_get)
  end
end
