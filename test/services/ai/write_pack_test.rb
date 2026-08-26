require "test_helper"

class WritePackTest < ActiveSupport::TestCase
  test "template fallback returns channel copy and seller report" do
    without_env("OPENROUTER_API_KEY", "OPENAI_API_KEY") do
      listing = listings(:bgc_condo)
      copy = Ai::WritePack.new(listing: listing).call

      assert_includes copy[:facebook_caption], "BGC"
      assert_includes copy[:marketplace_caption], "Pag-IBIG"
      assert_includes copy[:messenger_followup], "Parking"
      assert copy[:seller_report].present?
      assert copy[:facebook_group_caption].present?
      assert_equal "template_fallback", copy[:model]
    end
  end

  test "price reduced copy mentions the old price" do
    without_env("OPENROUTER_API_KEY", "OPENAI_API_KEY") do
      listing = listings(:bgc_condo)
      listing.stage = "price_reduced"
      listing.previous_price_amount = 13_500_000
      copy = Ai::WritePack.new(listing: listing).call

      assert_includes copy[:facebook_caption], "Price reduced"
      assert_includes copy[:facebook_caption], "13,500,000"
    end
  end
end
