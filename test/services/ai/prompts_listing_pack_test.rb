require "test_helper"

class PromptsListingPackTest < ActiveSupport::TestCase
  test "user prompt includes angles and past examples" do
    listing = listings(:bgc_condo)
    brand = listing.user.brand_kit
    prompt = Prompts::ListingPack.user_prompt(
      listing: listing,
      photo_notes: nil,
      brand: brand,
      angles: { primary: "Parking included", angles: [ "Parking included", "Pag-IBIG welcome" ] },
      past_examples: "Example 1 (past pack · BGC · Just listed — mimic tone only, not facts):\nHello BGC"
    )

    assert_includes prompt, "Primary angle: Parking included"
    assert_includes prompt, "Pag-IBIG welcome"
    assert_includes prompt, "Hello BGC"
    assert_equal "listing_pack_v4", Prompts::ListingPack::VERSION
  end
end
