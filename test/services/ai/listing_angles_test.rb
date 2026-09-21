require "test_helper"

class AiListingAnglesTest < ActiveSupport::TestCase
  test "builds primary and supporting angles from listing fields" do
    listing = listings(:bgc_condo)
    result = Ai::ListingAngles.new(listing).call

    assert_includes result[:primary], "Just listed"
    assert result[:angles].any? { |a| a.include?("Parking") }
    assert result[:angles].any? { |a| a.include?("Pag-IBIG") }
    assert result[:angles].any? { |a| a.include?("BGC Bus") }
    assert result[:angles].any? { |a| a.include?("60-day") }
  end

  test "price reduced angle mentions old and new price" do
    listing = listings(:bgc_condo)
    listing.stage = "price_reduced"
    listing.previous_price_amount = 13_500_000
    result = Ai::ListingAngles.new(listing).call

    assert_includes result[:primary], "Price reduced"
    assert_includes result[:primary], "13,500,000"
  end
end
