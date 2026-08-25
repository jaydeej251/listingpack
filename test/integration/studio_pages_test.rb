require "test_helper"

class StudioPagesTest < ActionDispatch::IntegrationTest
  test "landing explains graphic seller recap and empty week" do
    get root_path
    assert_response :success
    assert_select "h1", /Upload a listing/
    assert_select "h2", "The graphic"
    assert_select "h2", "The seller recap"
    assert_select "h2", "The empty week"
    assert_select "footer", /Log in/
  end

  test "landing shows a rendered example inside each of the three cards" do
    get root_path
    assert_response :success

    assert_select ".poster-mock", minimum: 3
    assert_select ".poster-price", text: /₱12,500,000/
    assert_select "svg[role=img]", minimum: 1

    assert_match "Weekly seller update", response.body
    assert_match "Week 2", response.body
    assert_match "Viewings", response.body

    assert_match "Market pulse", response.body
    assert_match "Open house invite", response.body
  end

  test "landing previews per-channel copy behind tabs" do
    get root_path
    assert_response :success

    assert_select "[data-controller=tabs]"
    assert_select "[data-tabs-target=tab]", 4
    assert_select "[data-tabs-target=panel]", 4
    assert_match "Marketplace listing", response.body
  end

  test "landing closes with pricing and a sign-up call to action" do
    get root_path
    assert_response :success

    assert_select "h3", "Free"
    assert_select "h3", "Pro"
    assert_select "a[href=?]", new_registration_path, minimum: 3
    assert_select "details summary", minimum: 3
  end

  test "listings index shows photo card with stage and pack pills" do
    sign_in users(:one)
    get listings_path
    assert_response :success
    assert_select "p", "2BR at The Fort Residences"
    assert_select "span", "Just listed"
    assert_select "span", "Draft"
    assert_select "a", "New listing"
  end

  test "empty listings shows first-pack empty state" do
    sign_in users(:two)
    get listings_path
    assert_response :success
    assert_select "h2", "No listings yet"
    assert_select "a", "New listing"
  end

  test "generating pack shows stepper not a single paragraph" do
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.update!(status: "generating")

    get status_listing_content_packs_path(listing)
    assert_response :success
    assert_select "h2", "Building this pack"
    assert_select "li", /Writing captions/
  end

  test "ready pack uses copy tabs and says png is optional" do
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.update!(status: "ready", price_confirmed: false)
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Just listed sa BGC")
    GeneratedAsset::TEMPLATE_KEYS.each { |key| pack.generated_assets.create!(template_key: key) }

    get status_listing_content_packs_path(listing)
    assert_response :success
    assert_select "h2", "Captions and follow-ups"
    assert_select "button", "Post"
    assert_select "button", "Marketplace"
    assert_match "PNG not ready", response.body
    assert_match "Confirm the asking price", response.body
  end

  test "this week empty state includes a sample monday post" do
    sign_in users(:two)
    get weekly_calendars_path
    assert_response :success
    assert_select "h2", "No week generated yet"
    assert_select "p", /Monday/
  end

  test "this week show lists generated posts" do
    sign_in users(:two)
    calendar = users(:two).weekly_calendars.create!(
      week_start: Time.zone.today.beginning_of_week.to_date,
      focus_area: "BGC",
      status: "ready",
      posts: [ { "day" => "Monday", "title" => "Market pulse", "body" => "Parking still wins in BGC." } ]
    )

    get weekly_calendar_path(calendar)
    assert_response :success
    assert_select "h2", "Market pulse"
    assert_select "button", "Copy"
  end

  test "brand kit shows color preview and first-run steps for users with no listings" do
    sign_in users(:two)
    get edit_brand_kit_path
    assert_response :success
    assert_select "h1", "Brand kit"
    assert_select "[data-controller='brand-preview']"
    assert_select "li", /Brand kit/
  end

  test "auth pages use the shared field and button classes" do
    get new_session_path
    assert_response :success
    assert_select "input.field"
    assert_select "input.btn"
  end

  private
    def sign_in(user)
      post session_url, params: { email_address: user.email_address, password: "password" }
      follow_redirect!
    end
end
