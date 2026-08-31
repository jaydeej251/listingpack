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

  test "creates a share token" do
    listing = users(:one).listings.new(
      title: "Studio in Makati",
      location: "Makati",
      language: "taglish",
      stage: "listed",
      listing_type: "for_sale",
      financing: "negotiable"
    )
    listing.photos.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "x.png", content_type: "image/png")

    assert listing.save
    assert_match(/\A[A-Za-z0-9]+\z/, listing.share_token)
    assert_equal 16, listing.share_token.length
  end

  test "share text includes title price and location" do
    listing = listings(:bgc_condo)
    assert_includes listing.share_text, listing.title
    assert_includes listing.share_text, "BGC, Taguig"
    assert_includes listing.share_text, "₱12,500,000"
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
