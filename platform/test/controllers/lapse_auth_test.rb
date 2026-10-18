require "test_helper"

class LapseAuthTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:member) }

  test "connects Lapse with PKCE and copies the timelapses in the background" do
    with_lapse do
      get connect_lapse_path(return_to: "/projects/x#write")
      query = Rack::Utils.parse_query(URI(response.location).query)
      assert_equal "S256", query["code_challenge_method"]

      exchanged = nil
      Lapse.define_singleton_method(:exchange_code) { |_code, _uri, code_verifier:| exchanged = code_verifier and "lapse-token" }
      assert_enqueued_with(job: SyncLapseTimelapsesJob, args: [ users(:member) ]) do
        get lapse_callback_path(code: "abc", state: query["state"])
      end
      assert_redirected_to "/projects/x#write"
      assert_equal query["code_challenge"], Base64.urlsafe_encode64(Digest::SHA256.digest(exchanged), padding: false)
      assert_equal "lapse-token", users(:member).reload.lapse_token
    end
  end

  test "refuses a callback without a state it issued" do
    with_lapse { get lapse_callback_path(code: "abc", state: "forged") }
    assert_match(/state mismatch/, flash[:alert])
    assert_not users(:member).reload.lapse_connected?
  end

  test "disconnecting forgets the token" do
    users(:member).update!(lapse_token: "lapse-token")
    delete disconnect_lapse_path
    assert_not users(:member).reload.lapse_connected?
  end

  test "the composer can ask for a fresh copy" do
    assert_no_enqueued_jobs(only: SyncLapseTimelapsesJob) { post lapse_sync_path }
    users(:member).update!(lapse_token: "lapse-token")
    assert_enqueued_with(job: SyncLapseTimelapsesJob) { post lapse_sync_path }
  end

  private

  def with_lapse(&block)
    original = Lapse.method(:exchange_code)
    with_env("LAPSE_CLIENT_ID" => "svc_test", "LAPSE_CLIENT_SECRET" => "scs_test", &block)
  ensure
    Lapse.define_singleton_method(:exchange_code, original)
  end
end
