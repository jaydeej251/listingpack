require "test_helper"

class ListingShareTest < ActionDispatch::IntegrationTest
  test "public listing page is visible without signing in" do
    listing = listings(:bgc_condo)
    listing.photos.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "x.png", content_type: "image/png")
    listing.user.brand_kit.update!(display_name: "Maria Santos", phone: "0917 000 0000")

    get public_listing_path(listing.share_token)
    assert_response :success
    assert_select "h1", listing.title
    assert_match "Maria Santos", response.body
    assert_select "meta[property='og:title'][content=?]", listing.title
  end

  test "unknown share token is not found" do
    get public_listing_path("missingToken1234")
    assert_response :not_found
  end

  test "free listings index sends share to plan" do
    sign_in users(:one)
    get listings_path
    assert_response :success
    assert_select "a[href=?]", billing_path, text: "Share on Pro"
    assert_no_match "facebook.com/sharer", response.body
  end

  test "pro listings index includes facebook share" do
    listing = listings(:bgc_condo)
    listing.user.update!(plan: "pro")
    sign_in listing.user

    get listings_path
    assert_response :success
    assert_match "facebook.com/sharer", response.body
    assert_match "/l/#{listing.share_token}", response.body
    assert_select "a", text: "Facebook"
    assert_select "a", text: "WhatsApp"
    assert_select "button", text: "Copy link"
    assert_no_match "Share on Pro", response.body
  end

  test "pro listing show includes facebook share" do
    listing = listings(:bgc_condo)
    listing.user.update!(plan: "pro")
    sign_in listing.user

    get listing_path(listing)
    assert_response :success
    assert_select "h2", "Share"
    assert_match "facebook.com/sharer", response.body
  end

  test "free listing show prompts upgrade instead of facebook" do
    sign_in users(:one)
    get listing_path(listings(:bgc_condo))
    assert_response :success
    assert_select "h2", "Share"
    assert_select "a[href=?]", billing_path, text: "Share on Pro"
    assert_no_match "facebook.com/sharer", response.body
  end

  test "plan page lists pro share and coming pro plus" do
    sign_in users(:one)
    get billing_path
    assert_response :success
    assert_match "Share to Facebook", response.body
    assert_select "h2", "Pro Plus"
    assert_match "₱#{User::PRO_PLUS_INTRO_PRICE_PHP}", response.body
    assert_match "Not for sale yet", response.body
  end

  private
    def sign_in(user)
      post session_url, params: { email_address: user.email_address, password: "password" }
      follow_redirect!
    end
end
