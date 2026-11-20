require "test_helper"

class WorkshopGuidesTest < ActionDispatch::IntegrationTest
  test "the guide opens on the PCB part without an account" do
    assert_equal "pcb", inertia_props(workshop_guide_path, "WorkshopGuides/Show")["part"]
  end

  test "each other part has its own address" do
    %w[cad firmware submit].each do |part|
      assert_equal part, inertia_props(workshop_guide_path(page: part), "WorkshopGuides/Show")["part"]
    end
  end

  test "an old section address lands on that section of the PCB part" do
    get workshop_guide_path(page: "schematic")
    assert_redirected_to workshop_guide_path(anchor: "schematic")
  end

  test "the old walkthrough addresses move to the same part" do
    get tamagotchi_guide_path(page: "firmware")
    assert_redirected_to workshop_guide_path(page: "firmware")

    get tamagotchi_guide_path(page: "pcb")
    assert_redirected_to workshop_guide_path
  end
end
