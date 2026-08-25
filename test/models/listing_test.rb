require "test_helper"

class ListingTest < ActiveSupport::TestCase
  test "ph badges include parking and financing" do
    listing = listings(:bgc_condo)
    assert_includes listing.ph_badges, "Parking included"
    assert_includes listing.ph_badges, "Pag-IBIG"
    assert_equal "JUST LISTED", listing.stage_banner
  end

  test "pack status is separate from listing stage" do
    listing = listings(:bgc_condo)
    assert_equal "Just listed", listing.stage_label
    assert_equal "Draft", listing.pack_status_label

    listing.status = "generating"
    assert_equal "Generating", listing.pack_status_label

    listing.status = "failed"
    assert_equal "Failed", listing.pack_status_label

    listing.status = "ready"
    assert_equal "Ready", listing.pack_status_label
  end

  test "price reduced requires previous price" do
    listing = listings(:bgc_condo)
    listing.stage = "price_reduced"
    listing.previous_price_amount = nil
    assert_not listing.valid?
    assert_includes listing.errors[:previous_price_amount], "add the old price when the stage is price reduced"

    listing.previous_price_amount = 13_000_000
    assert listing.valid?
  end
end
