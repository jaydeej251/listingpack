require "test_helper"

class ImagesBeautyPromptTest < ActiveSupport::TestCase
  test "includes listing facts and safe-zone rules" do
    listing = listings(:bgc_condo)
    prompt = Images::BeautyPrompt.new(listing: listing).call

    assert_includes prompt, "highly converting"
    assert_includes prompt, "CENTER 60%"
    assert_includes prompt, listing.title
    assert_includes prompt, listing.location
    assert_includes prompt, "HERO"
    assert_includes prompt, "Do NOT render phone numbers"
  end
end
