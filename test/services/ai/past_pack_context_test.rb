require "test_helper"

class AiPastPackContextTest < ActiveSupport::TestCase
  setup do
    @listing = listings(:bgc_condo)
    @user = @listing.user
  end

  test "returns empty examples when agent has no past packs" do
    result = Ai::PastPackContext.new(@listing).call
    assert_empty result[:examples]
    assert_includes result[:prompt_block], "none yet"
  end

  test "prefers same-location ready packs for tone examples" do
    other = @user.listings.new(
      title: "1BR near Uptown",
      location: "BGC, Taguig",
      price_amount: 8_000_000,
      language: "taglish",
      status: "ready",
      stage: "listed",
      listing_type: "for_sale",
      financing: "pag_ibig",
      parking: true,
      share_token: "pastPackBgcToken01"
    )
    other.save!(validate: false)
    other.content_packs.create!(
      language: "taglish",
      status: "ready",
      stage: "listed",
      facebook_caption: "Just listed sa BGC mga sis — parking included. DM for viewing this week."
    )

    far = @user.listings.new(
      title: "Lot in Batangas",
      location: "Batangas City",
      price_amount: 2_000_000,
      language: "taglish",
      status: "ready",
      stage: "listed",
      listing_type: "for_sale",
      financing: "cash",
      parking: false,
      share_token: "pastPackFarToken02"
    )
    far.save!(validate: false)
    far.content_packs.create!(
      language: "taglish",
      status: "ready",
      stage: "listed",
      facebook_caption: "Batangas lot for sale — cash buyers preferred."
    )

    result = Ai::PastPackContext.new(@listing).call
    assert_equal 2, result[:examples].size
    assert_includes result[:examples].first[:facebook_caption], "BGC"
    assert_includes result[:prompt_block], "tone only"
  end
end
