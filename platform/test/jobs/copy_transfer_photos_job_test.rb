require "test_helper"

class CopyTransferPhotosJobTest < ActiveJob::TestCase
  STARDANCE = "https://stardance.hackclub.com/rails/active_storage/leg%20one.png"
  ELSEWHERE = "https://example.com/tracker.png"

  test "copies photos from the program's own hosts onto the journal and takes their links out" do
    journal = transferred_journal("Built it.\n\n[Photo 1](#{STARDANCE})\n[Photo 2](#{ELSEWHERE})\n\n_Transferred from https://stardance.hackclub.com/projects/1_")

    with_download(file_fixture("pixel.png").binread) { CopyTransferPhotosJob.perform_now(journal) }

    journal.reload
    assert_equal [ "leg one.png" ], journal.images.map { it.filename.to_s }
    assert_equal [ STARDANCE, users(:member).id ], journal.images.first.blob.metadata.values_at("source_url", Journal::UPLOADER_KEY)
    assert_equal "Built it.\n\n[Photo 2](#{ELSEWHERE})\n\n_Transferred from https://stardance.hackclub.com/projects/1_", journal.body

    with_download(file_fixture("pixel.png").binread) { CopyTransferPhotosJob.perform_now(journal) }
    assert_equal 1, journal.reload.images.count, "a second run copies nothing twice"
  end

  test "a download that isn't a photo stays a link" do
    journal = transferred_journal("Built it.\n\n[Photo 1](#{STARDANCE})")
    with_download("<html>Sign in</html>") { CopyTransferPhotosJob.perform_now(journal) }

    assert_empty journal.reload.images
    assert_includes journal.body, "[Photo 1](#{STARDANCE})"
  end

  test "follows the photo host's redirect to where it keeps the file" do
    journal = transferred_journal("Built it.\n\n[Photo 1](#{STARDANCE})")
    responses = [
      Faraday::Response.new(status: 302, body: "", response_headers: { "location" => "https://bucket.example-storage.com/leg.png" }),
      Faraday::Response.new(status: 200, body: file_fixture("pixel.png").binread, response_headers: {})
    ]
    stub_method(Faraday, :get, nil) do
      Faraday.define_singleton_method(:get) { |*| responses.shift }
      CopyTransferPhotosJob.perform_now(journal)
    end

    assert_equal 1, journal.reload.images.count
    assert_not_includes journal.body, "[Photo 1]"
  end

  test "approving a transfer queues the copy for journals with photos" do
    assert_enqueued_jobs(1, only: CopyTransferPhotosJob) do
      project_transfers(:stardance).approve(reviewer: users(:admin), minutes: 60, xp: 8)
    end
  end

  private

  def transferred_journal(body)
    projects(:station).journals.create!(user: users(:member), source: "transfer", body: body, duration_minutes: 60)
  end

  def with_download(body, &)
    stub_method(Faraday, :get, Faraday::Response.new(status: 200, body: body, response_headers: {}), &)
  end
end
