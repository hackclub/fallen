require "test_helper"

class JobBoardTest < ActiveSupport::TestCase
  test "arguments read without Active Job's serialization markers" do
    arguments = [
      { "_aj_globalid" => "gid://fallen/Project/7" },
      { "note" => "hi", "_aj_symbol_keys" => [ "note" ] },
      { "_aj_serialized" => "ActiveJob::Serializers::TimeWithZoneSerializer", "value" => "2026-10-20T12:00:00Z" }
    ]
    assert_equal [ "Project#7", { "note" => "hi" }, "2026-10-20T12:00:00Z" ], JobBoard.readable(arguments)
  end
end
