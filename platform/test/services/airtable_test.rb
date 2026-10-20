require "test_helper"

class AirtableTest < ActiveSupport::TestCase
  test "configured only with a key and a base" do
    with_env("AIRTABLE_API_KEY" => "pat", "AIRTABLE_BASE_ID" => "app1") { assert Airtable.configured? }
    with_env("AIRTABLE_API_KEY" => nil, "AIRTABLE_BASE_ID" => "app1") { assert_not Airtable.configured? }
  end

  test "sync uploads the rows as one CSV with a header" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.post("/v0/app1/Users/sync/sync1") do |env|
      assert_equal "text/csv", env.request_headers["Content-Type"]
      assert_equal "ID,Name,Roles\nusr_1,\"Ada, L\",\"user,admin\"\nusr_2,,user\n", env.body
      [ 200, {}, { success: true }.to_json ]
    end

    rows = [ { "ID" => "usr_1", "Name" => "Ada, L", "Roles" => %w[user admin] }, { "ID" => "usr_2", "Name" => nil, "Roles" => %w[user] } ]
    with_airtable(stubs) { Airtable.sync("Users", "sync1", rows) }
    stubs.verify_stubbed_calls
  end

  test "a refused upload raises" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.post("/v0/app1/Users/sync/sync1") { [ 422, {}, { error: { type: "INVALID_REQUEST" } }.to_json ] }

    error = with_airtable(stubs) { assert_raises(Airtable::Error) { Airtable.sync("Users", "sync1", [ { "ID" => "usr_1" } ]) } }
    assert_includes error.message, "INVALID_REQUEST"
  end

  test "more rows than one upload takes are refused before sending" do
    rows = Array.new(Airtable::MAX_ROWS + 1) { |i| { "ID" => i } }
    with_airtable(Faraday::Adapter::Test::Stubs.new) { assert_raises(Airtable::Error) { Airtable.sync("Users", "sync1", rows) } }
  end

  test "a page that can't connect is asked for again" do
    calls = 0
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/v0/app2/tbl1") do
      calls += 1
      raise Faraday::ConnectionFailed, "execution expired" if calls == 1

      [ 200, {}, { records: [ { id: "rec1", fields: { "fld1" => "a" } } ] }.to_json ]
    end

    stub_method(Airtable, :sleep, nil) do
      assert_equal [ { "fld1" => "a" } ], with_airtable(stubs) { Airtable.records("app2", "tbl1", fields: %w[fld1]) }
    end
    assert_equal 2, calls
  end

  test "a page that keeps failing to connect raises" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/v0/app2/tbl1") { raise Faraday::ConnectionFailed, "execution expired" }

    stub_method(Airtable, :sleep, nil) do
      assert_raises(Faraday::ConnectionFailed) { with_airtable(stubs) { Airtable.records("app2", "tbl1", fields: %w[fld1]) } }
    end
  end

  private

  def with_airtable(stubs, &block)
    with_env("AIRTABLE_API_KEY" => "pat", "AIRTABLE_BASE_ID" => "app1") do
      connection = Airtable.connection
      connection.adapter(:test, stubs)
      stub_method(Airtable, :connection, connection, &block)
    end
  end
end
