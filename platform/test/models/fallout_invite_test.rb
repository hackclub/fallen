require "test_helper"

# == Schema Information
#
# Table name: fallout_invites
#
#  digest :string           not null, primary key
#
class FalloutInviteTest < ActiveSupport::TestCase
  test "matches only the email and code pair, however they're cased" do
    FalloutInvite.create!(digest: FalloutInvite.digest("fan@example.com", "PPTMPR"))

    assert FalloutInvite.match?(" FAN@example.com", "pptmpr ")
    assert_not FalloutInvite.match?("fan@example.com", "PPTMPX")
    assert_not FalloutInvite.match?("other@example.com", "PPTMPR")
    assert_not FalloutInvite.match?("fan@example.com", nil)
  end

  test "keeps a keyed hash, never the email or code" do
    digest = FalloutInvite.digest("fan@example.com", "PPTMPR")
    assert_not_equal Digest::SHA256.hexdigest("fan@example.com\nPPTMPR"), digest
    assert_no_match(/fan|PPTMPR/i, digest)
  end

  test "sync replaces every pair with what Fallout's Airtable has, page by page" do
    FalloutInvite.create!(digest: FalloutInvite.digest("gone@example.com", "ZZZZZZ"))
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/v0/#{FalloutInvite::BASE}/#{FalloutInvite::USERS_TABLE}") do |env|
      assert_equal "Bearer pat-fallout", env.request_headers["Authorization"]
      assert_equal [ FalloutInvite::EMAIL_FIELD, FalloutInvite::CODE_FIELD ], env.params["fields"]
      page = env.params["offset"] ? { records: [ record("two@example.com", "HMXMHZ"), record("", "TTXXKX"), record("bad@example.com", "no") ] } : { records: [ record("One@Example.com", "RPZRTK") ], offset: "p2" }
      [ 200, {}, page.to_json ]
    end

    stub_method(Airtable, :sleep, nil) do
      assert_equal 2, with_fallout_airtable(stubs) { FalloutInvite.sync }
    end
    assert FalloutInvite.match?("one@example.com", "RPZRTK")
    assert FalloutInvite.match?("two@example.com", "HMXMHZ")
    assert_not FalloutInvite.match?("gone@example.com", "ZZZZZZ")
  end

  test "an empty or failed read keeps the codes there are" do
    FalloutInvite.create!(digest: FalloutInvite.digest("fan@example.com", "PPTMPR"))
    [ [ 200, {}, { records: [] }.to_json ], [ 403, {}, { error: "NOT_AUTHORIZED" }.to_json ] ].each do |response|
      stubs = Faraday::Adapter::Test::Stubs.new
      stubs.get("/v0/#{FalloutInvite::BASE}/#{FalloutInvite::USERS_TABLE}") { response }
      assert_raises(Airtable::Error) { with_fallout_airtable(stubs) { FalloutInvite.sync } }
    end
    assert FalloutInvite.match?("fan@example.com", "PPTMPR")
  end

  private

  def record(email, code) = { id: "rec#{code}", fields: { FalloutInvite::EMAIL_FIELD => email, FalloutInvite::CODE_FIELD => code }.compact_blank }

  def with_fallout_airtable(stubs, &block)
    with_env("FALLOUT_AIRTABLE_API_KEY" => "pat-fallout") do
      connection = Airtable.connection("pat-fallout")
      connection.adapter(:test, stubs)
      stub_method(Airtable, :connection, connection, &block)
    end
  end
end
