require "test_helper"

class AirtableTest < ActiveSupport::TestCase
  test "configured only with a key and a base" do
    with_env("AIRTABLE_API_KEY" => "pat", "AIRTABLE_BASE_ID" => "app1") { assert Airtable.configured? }
    with_env("AIRTABLE_API_KEY" => nil, "AIRTABLE_BASE_ID" => "app1") { assert_not Airtable.configured? }
  end

  test "upsert sends records in tens, merged on the given field" do
    bodies = []
    stubs = Faraday::Adapter::Test::Stubs.new
    2.times { stubs.patch("/v0/app1/Users") { |env| bodies << JSON.parse(env.body); [ 200, {}, { records: [] }.to_json ] } }

    with_airtable(stubs) do
      stub_method(Airtable, :sleep, nil) do
        Airtable.upsert("Users", Array.new(12) { |i| { "ID" => "usr_#{i}" } }, merge_on: "ID")
      end
    end

    assert_equal [ 10, 2 ], bodies.map { |body| body["records"].size }
    assert_equal({ "fieldsToMergeOn" => [ "ID" ] }, bodies.first["performUpsert"])
    assert_equal({ "fields" => { "ID" => "usr_0" } }, bodies.first["records"].first)
    stubs.verify_stubbed_calls
  end

  test "a refused request raises" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.patch("/v0/app1/Users") { [ 422, {}, { error: { type: "UNKNOWN_FIELD_NAME" } }.to_json ] }

    error = with_airtable(stubs) { assert_raises(Airtable::Error) { Airtable.upsert("Users", [ { "Nope" => 1 } ], merge_on: "ID") } }
    assert_includes error.message, "UNKNOWN_FIELD_NAME"
  end

  test "delete_where finds records by formula, escaping quotes, and deletes them" do
    stubs = Faraday::Adapter::Test::Stubs.new
    formula = nil
    stubs.get("/v0/app1/Users") do |env|
      formula = env.params["filterByFormula"]
      [ 200, {}, { records: [ { id: "rec1" }, { id: "rec2" } ] }.to_json ]
    end
    stubs.delete("/v0/app1/Users") do |env|
      assert_equal "records[]=rec1&records[]=rec2", CGI.unescape(env.url.query)
      [ 200, {}, { records: [] }.to_json ]
    end

    assert_equal 2, with_airtable(stubs) { Airtable.delete_where("Users", "ID", [ "usr_1", "it's" ]) }
    assert_equal "OR({ID} = 'usr_1', {ID} = 'it\\'s')", formula
    stubs.verify_stubbed_calls
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
