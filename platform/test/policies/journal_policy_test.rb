require "test_helper"

class JournalPolicyTest < ActiveSupport::TestCase
  test "owners edit their journals, except transferred ones, whose hours a reviewer set" do
    journal = journals(:first)
    assert JournalPolicy.new(journal.user, journal).update?

    journal.source = "transfer"
    assert_not JournalPolicy.new(journal.user, journal).update?
    assert JournalPolicy.new(journal.user, journal).destroy?
  end
end
