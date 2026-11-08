require "test_helper"

class TransferLapseReviewTest < ActiveSupport::TestCase
  TOKEN = "94a23d0a72d42cc7494c071dee7aea9a8f85ab9b466a34a4465ae11e0b182491".freeze

  setup { @transfer = project_transfers(:stardance) }

  test "the reviewer types the Hackatime account and projects; nothing else fills them in" do
    assert @transfer.request_lapse(user_id: " 599 ", projects: "river, spark ,river,")
    assert_equal [ "599", %w[river spark] ], @transfer.values_at(:hackatime_user_id, :hackatime_projects)
    assert @transfer.lapse_fetching?

    assert_not @transfer.request_lapse(user_id: "U079JDRMBFZ", projects: "river")
    assert @transfer.errors[:hackatime_user_id].any?
  end

  test "finds the Lapse and Lookout recordings in the projects' heartbeats and looks each one up" do
    @transfer.request_lapse(user_id: "599", projects: "river")
    hackatime = Faraday::Adapter::Test::Stubs.new
    hackatime.get("/api/admin/v1/user/heartbeats") do |env|
      beats = if env.params["editor"] == "lapse"
        [ beat("henry vs river kicad part 11 (1p0bWQIUGV9k)", 1_786_919_712, editor: "lapse", language: "Lapse"),
          beat("henry vs river kicad part 11 (1p0bWQIUGV9k)", 1_786_919_772, editor: "lapse", language: "Lapse"),
          beat("an old one (gone12345678)", 1_786_000_000, editor: "lapse", language: "Lapse") ]
      else
        [ beat(TOKEN, 1_783_575_955, editor: nil, language: "Lookout") ]
      end
      [ 200, {}, { heartbeats: beats, has_more: false }.to_json ]
    end
    lapse = Faraday::Adapter::Test::Stubs.new
    lapse.get("/api/timelapse/query") do |env|
      next [ 200, {}, { ok: false, error: "NOT_FOUND" }.to_json ] unless env.params["id"] == "1p0bWQIUGV9k"

      [ 200, {}, { ok: true, data: { timelapse: { name: "henry vs river kicad part 11", visibility: "UNLISTED", createdAt: 1_786_919_328_453, duration: 15_000,
                                                   playbackUrl: "https://lookout.test/v.mp4", thumbnailUrl: "https://lookout.test/t.jpg",
                                                   owner: { hackatimeId: "599", slackId: "U079JDRMBFZ" } } } }.to_json ]
    end
    lookout = Faraday::Adapter::Test::Stubs.new
    lookout.get("/api/sessions/#{TOKEN}") do
      [ 200, {}, { name: "untitled", status: "complete", trackedSeconds: 4020, startedAt: "2026-07-09T05:19:55.396Z", videoUrl: "https://lookout.test/l.mp4" }.to_json ]
    end

    stub_method(Hackatime, :connection, Faraday.new(url: Hackatime::HOST) { it.adapter :test, hackatime }) do
      stub_method(Lapse, :connection, Faraday.new { it.adapter :test, lapse }) do
        stub_method(Lookout, :connection, Faraday.new { it.adapter :test, lookout }) do
          with_env("HACKATIME_ADMIN_API_KEY" => "key") { @transfer.fetch_lapse! }
        end
      end
    end

    recordings = @transfer.reload.lapse_recordings
    assert_nil @transfer.lapse_error
    assert_equal [ "lookout", "lapse", "lapse" ], recordings.pluck("kind")
    lookout_one, gone, river = recordings
    assert_equal [ 4020, false, "river" ], lookout_one.values_at("seconds", "missing", "project")
    assert_not_includes lookout_one.to_json, TOKEN
    assert_equal [ true, 0, "an old one" ], gone.values_at("missing", "seconds", "name")
    assert_equal [ "lapse:1p0bWQIUGV9k", 15_000, 2, "599" ], river.values_at("key", "seconds", "heartbeats", "owner_hackatime_id")
    assert_equal 19_020, @transfer.lapse_seconds
  end

  test "a Hackatime failure is kept as the error" do
    @transfer.request_lapse(user_id: "599", projects: "river")
    with_env("HACKATIME_ADMIN_API_KEY" => nil) { @transfer.fetch_lapse! }
    assert_equal "HACKATIME_ADMIN_API_KEY is not set", @transfer.reload.lapse_error
    assert_not @transfer.lapse_fetching?
  end

  test "removed time comes off whole and deflated time by its share, scaled by the video's length" do
    @transfer.update!(lapse_recordings: [ { "key" => "lapse:a", "seconds" => 6_000 }, { "key" => "lapse:b", "seconds" => 600 } ])
    assert @transfer.annotate_lapse(
      "lapse:a" => { "reviewed" => "true", "video_seconds" => 100, "description" => " Soldering ",
                     "segments" => [ { "type" => "removed", "start" => 0, "end" => 10, "reason" => "AFK" },
                                     { "type" => "deflated", "start" => 50, "end" => 70, "reason" => "Tutorial", "percent" => 50 },
                                     { "type" => "removed", "start" => 60, "end" => 80, "reason" => "Overlaps the last one" },
                                     { "type" => "bogus", "start" => 0, "end" => 1 } ] },
      "lapse:nope" => { "reviewed" => true }
    )

    # 6000s over a 100s video is 60s a video second: 600s removed, half of 1200s deflated.
    assert_equal 6_000 - 600 - 600 + 600, @transfer.lapse_seconds
    note = @transfer.lapse_annotations["lapse:a"]
    assert_equal [ true, "Soldering", 2 ], [ note["reviewed"], note["description"], note["segments"].size ]
    assert_equal [ "lapse:a" ], @transfer.lapse_annotations.keys
  end

  private

  def beat(entity, time, editor:, language:) = { time: time.to_f, project: "river", entity: entity, editor: editor, language: language }
end
