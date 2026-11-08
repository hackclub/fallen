require "test_helper"

class BomImportTest < ActiveSupport::TestCase
  test "reads named columns in any order, with totals worked out from unit prices" do
    result = BomImport.parse(<<~CSV)
      Item,Description,Quantity,Price (USD),Total,Supplier,URL
      RP2040,Microcontroller,2,0.80,,LCSC,https://lcsc.com/x
      PCB,5 boards,5,,$7.00,JLCPCB,https://jlcpcb.com
      Shipping,,,,$12,,
      Total,,,,$20.60,,
    CSV

    rp, pcb, shipping = result.items
    assert_equal [ "RP2040", 2, 80, 160, "https://lcsc.com/x", "LCSC" ], rp.to_h.values_at(:name, :quantity, :unit_cents, :total_cents, :link, :vendor)
    assert_equal [ 5, 140, 700 ], pcb.to_h.values_at(:quantity, :unit_cents, :total_cents)
    assert_equal [ "shipping", 1200 ], shipping.to_h.values_at(:kind, :total_cents)
    assert_equal 3, result.items.size, "the Total row is a summary, not a part"
    assert_equal 2060, result.stated_total_cents
    assert_empty result.warnings
  end

  test "semicolons, European decimals and other currencies" do
    result = BomImport.parse("Name;Qty;Cost;Link\nWiderstand;10;1,50 €;https://reichelt.de/a\n")

    assert_equal [ 10, 150 ], result.items.first.to_h.values_at(:quantity, :total_cents)
    assert_match "US dollars", result.warnings.join
  end

  test "guesses the columns of a file with no header row" do
    result = BomImport.parse("Switches,70,$25,https://kbdfans.com\nKeycaps,1,$30,https://x.com\n")

    assert_equal [ [ "Switches", 70, 2500 ], [ "Keycaps", 1, 3000 ] ], result.items.map { it.to_h.values_at(:name, :quantity, :total_cents) }
    assert_match "no header row", result.warnings.join
  end

  test "parts already owned, and a file total that doesn't add up" do
    result = BomImport.parse("Component,Qty,Unit cost,Owned?\nArduino Nano,1,$5,yes\nWire,1,$3,\nTotal,,$50,\n")

    assert result.items.first.owned
    assert_match "doesn't match its rows", result.warnings.join
  end

  test "amounts" do
    assert_equal 123_450, BomImport.cents("$1,234.50")
    assert_equal 123_450, BomImport.cents("1.234,50 €")
    assert_equal 1200, BomImport.cents("12 USD")
    assert_equal 0, BomImport.cents("free")
    assert_nil BomImport.cents("ask me")
  end

  test "never fails on junk" do
    assert_equal "That file has no rows", BomImport.parse("").warnings.first
    assert_kind_of BomImport::Result, BomImport.parse("\"unterminated,quote\nmore")
  end
end
