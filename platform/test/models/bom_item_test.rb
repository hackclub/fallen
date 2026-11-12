require "test_helper"

# == Schema Information
#
# Table name: bom_items
#
#  id             :bigint           not null, primary key
#  approved_cents :integer
#  kind           :string           default("part"), not null
#  link           :string
#  name           :string           not null
#  owned          :boolean          default(FALSE), not null
#  position       :integer          not null
#  purpose        :string
#  quantity       :integer          default(1), not null
#  reason         :string
#  total_cents    :integer          not null
#  unit_cents     :integer
#  vendor         :string
#  verdict        :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  submission_id  :bigint           not null
#
# Indexes
#
#  index_bom_items_on_submission_id  (submission_id)
#
# Foreign Keys
#
#  fk_rails_...  (submission_id => submissions.id)
#
class BomItemTest < ActiveSupport::TestCase
  test "a part they already have doesn't need a real link" do
    owned = BomItem.new(name: "Stepper driver", owned: true, link: "Owned", total_cents: 0, position: 0)
    owned.validate

    assert_nil owned.link
    assert_empty owned.errors[:link]
  end

  test "a part they're asking for still needs a real link" do
    item = BomItem.new(name: "Camera", link: "Owned", total_cents: 2000, position: 0)

    assert_not item.validate
    assert_includes item.errors[:link], "must start with http(s)://"
  end
end
