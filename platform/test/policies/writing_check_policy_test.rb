require "test_helper"

class WritingCheckPolicyTest < ActiveSupport::TestCase
  test "checks run only for people the flag is on for, once Pangram is set up" do
    member = users(:member)
    Flipper.enable(:writing_check)
    assert_not WritingCheckPolicy.new(member, WritingCheck).create?
    with_env("PANGRAM_API_KEY" => "key") do
      assert WritingCheckPolicy.new(member, WritingCheck).create?
      Flipper.disable(:writing_check)
      assert_not WritingCheckPolicy.new(member, WritingCheck).create?
    end
  end

  test "disable_pangram sends nothing and leaves the composer the paste reminder" do
    member = users(:member)
    Flipper.enable(:writing_check)
    Flipper.enable(:disable_pangram)
    with_env("PANGRAM_API_KEY" => "key") do
      assert_equal "paste", WritingCheck.mode_for(member)
      assert_not WritingCheckPolicy.new(member, WritingCheck).create?
      Flipper.disable(:writing_check)
      assert_nil WritingCheck.mode_for(member)
    end
  end

  test "only the writer sees a check" do
    check = WritingCheck.new(user: users(:member), body: "x")
    assert WritingCheckPolicy.new(users(:member), check).show?
    assert_not WritingCheckPolicy.new(users(:admin), check).show?
  end
end
