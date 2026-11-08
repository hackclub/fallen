require "test_helper"

class AdminTransferLapsesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    sign_in_as users(:admin)
    @transfer = project_transfers(:stardance)
  end

  test "looking someone up saves what the reviewer typed and fetches in a job" do
    patch admin_transfer_lapse_path(@transfer), params: { lapse: { hackatime_user_id: "599", hackatime_projects: "river, spark" } }

    assert_redirected_to admin_transfer_lapse_path(@transfer)
    assert_equal [ "599", %w[river spark] ], @transfer.reload.values_at(:hackatime_user_id, :hackatime_projects)
    assert_enqueued_with(job: FetchTransferLapseJob, args: [ @transfer ])
  end

  test "a Hackatime id that isn't a number is refused" do
    patch admin_transfer_lapse_path(@transfer), params: { lapse: { hackatime_user_id: "U0123", hackatime_projects: "river" } }

    assert_nil @transfer.reload.hackatime_user_id
    assert_no_enqueued_jobs(only: FetchTransferLapseJob)
  end

  test "the page shows the recordings and where else each was counted" do
    @transfer.update!(hackatime_user_id: "599", hackatime_projects: [ "river" ], lapse_fetched_at: Time.current,
                      lapse_recordings: [ { "key" => "lapse:LAPSE1", "kind" => "lapse", "seconds" => 3600 }, { "key" => "lapse:ELSEWHERE", "kind" => "lapse", "seconds" => 60 } ])
    project_transfers(:stranger).update!(lapse_recordings: [ { "key" => "lapse:ELSEWHERE", "seconds" => 60 } ])
    LapseTimelapse.create!(user: users(:member), lapse_id: "LAPSE1", journal: journals(:first))

    props = inertia_props(admin_transfer_lapse_path(@transfer), "Admin/TransferLapses/Show")
    counted = props["transfer"]["recordings"].to_h { [ it["key"], it["counted"] ] }
    assert_equal [ "a journal on #{journals(:first).project.title}" ], counted["lapse:LAPSE1"]
    assert_equal [ "transfer #{project_transfers(:stranger).public_id}" ], counted["lapse:ELSEWHERE"]
    assert props["can"]["review"]
  end

  test "annotations save as JSON and come back with the time that counts" do
    @transfer.update!(lapse_recordings: [ { "key" => "lapse:A", "seconds" => 600 } ])
    notes = { "lapse:A" => { "video_seconds" => 10, "segments" => [ { "type" => "removed", "start" => 0, "end" => 5, "reason" => "AFK" } ] } }
    patch annotations_admin_transfer_lapse_path(@transfer), params: { annotations: notes.to_json }, as: :json

    assert_response :success
    assert_equal 300, response.parsed_body["lapse_seconds"]
    assert_equal 300, @transfer.reload.lapse_seconds
  end

  test "a decided transfer's review can be read but not changed" do
    @transfer.update!(status: "approved", lapse_recordings: [ { "key" => "lapse:A", "seconds" => 600 } ])
    assert inertia_props(admin_transfer_lapse_path(@transfer), "Admin/TransferLapses/Show")["transfer"]["recordings"].any?

    patch annotations_admin_transfer_lapse_path(@transfer), params: { annotations: { "lapse:A" => { "reviewed" => true } }.to_json }, as: :json
    assert_response :redirect
    assert_equal({}, @transfer.reload.lapse_annotations)
  end

  test "people who don't review transfers can't see it" do
    sign_in_as users(:member)
    get admin_transfer_lapse_path(@transfer)
    assert_response :not_found
  end
end
