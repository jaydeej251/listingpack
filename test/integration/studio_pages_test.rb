require "test_helper"

class StudioPagesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  test "landing explains graphic seller recap and empty week" do
    get root_path
    assert_response :success
    assert_select "h1", /Upload a listing/
    assert_select "h1", /publish/
    assert_select ".hero-kicker", text: "ListingPack"
    assert_select ".hero-speed-mark", /in seconds/i
    assert_match(/Upload photos/, response.body)
    assert_match(/Pack generates/, response.body)
    assert_match(/The graphic/i, response.body)
    assert_match(/The seller recap/i, response.body)
    assert_match(/The empty week/i, response.body)
    assert_select "footer", /Log in/
  end

  test "landing shows format showcase in the hero" do
    get root_path
    assert_response :success

    assert_select ".hero-formats"
    assert_select ".hero-formats-stage"
    assert_select ".hero-formats-petal", 4
    assert_no_match "Hover to spread every format", response.body
    assert_match "Square post", response.body
    assert_match "Story · 9:16", response.body
    assert_match "Landscape · 16:9", response.body
    assert_match "Facebook banner", response.body
  end

  test "landing shows a rendered example inside each of the three stories" do
    get root_path
    assert_response :success

    assert_select ".poster-mock", minimum: 6
    assert_select ".poster-price", text: /₱12,500,000/
    assert_select "img[alt*='sample listing photo']", minimum: 1

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
    assert_select "[role=tab][aria-controls]", 4
    assert_match "Marketplace listing", response.body
  end

  test "landing closes with pricing and a sign-up call to action" do
    get root_path
    assert_response :success

    assert_select "h3", "Free"
    assert_select "h3", "Pro"
    assert_select "h3", "Pro Plus"
    assert_match(/₱#{User::PRO_PRICE_PHP}/, response.body)
    assert_match(/₱#{User::PRO_PLUS_INTRO_PRICE_PHP}/, response.body)
    assert_match(/Share to Facebook/, response.body)
    assert_no_match(/Facebook auto-post — coming later/, response.body)
    assert_select "a[href=?]", new_registration_path, minimum: 3
    assert_select "details summary", minimum: 3
    assert_match(/Pay with GCash/, response.body)
    assert_no_match(/nothing is charged today/i, response.body)
  end

  test "listings index shows photo card with stage and pack pills" do
    sign_in users(:one)
    get listings_path
    assert_response :success
    assert_select "p", "2BR at The Fort Residences"
    assert_select "span", "Just listed"
    assert_select "span", "Draft"
    assert_select "a", "New listing"
    assert_select "a", "Share on Pro"
    assert_no_match "facebook.com/sharer", response.body
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

  test "status json reports pack status and poster progress for polling" do
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Hi")
    pack.generated_assets.create!(template_key: "just_listed", status: "rendering")

    get status_listing_content_packs_path(listing, format: :json)
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "ready", body["status"]
    assert_equal false, body["posters_complete"]
    assert_equal 0, body["ready_count"]
    assert_equal GeneratedAsset.display_keys(user: listing.user).size, body["total_count"]
    assert_equal "rendering", body["posters"]["just_listed"]
  end

  test "posters endpoint redirects to listing when opened outside a turbo frame" do
    sign_in users(:one)
    listing = listings(:bgc_condo)

    get posters_listing_content_packs_path(listing)
    assert_redirected_to listing_path(listing)
  end

  test "posters frame endpoint returns fresh ready count" do
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.user.update!(plan: "pro")
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Just listed sa BGC")
    ready = pack.generated_assets.create!(template_key: "just_listed", status: "ready")
    ready.image.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "poster.png",
      content_type: "image/png"
    )
    pack.generated_assets.create!(template_key: "price_card", status: "ready")
    pack.generated_assets.create!(template_key: "agent_card", status: "rendering")

    get posters_listing_content_packs_path(listing), headers: { "Turbo-Frame" => "listing_posters" }
    assert_response :success
    assert_select "turbo-frame#listing_posters"
    assert_match(/2 of #{GeneratedAsset.display_keys(user: listing.user).size} ready/, response.body)
    assert_select "a", text: "Download PNG"
    assert_match(/Generating/, response.body)
  end

  test "listing show wires poster poll to posters frame endpoint" do
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Just listed sa BGC")
    pack.generated_assets.create!(template_key: "just_listed", status: "rendering")

    get listing_path(listing)
    assert_response :success
    assert_select "[data-poll-frame-url-value=?]", posters_listing_content_packs_path(listing)
  end

  test "generating listing polls until pack is ready not until all posters finish" do
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.update!(status: "generating")

    get listing_path(listing)
    assert_response :success
    assert_select "h2", "Building this pack"
    assert_select "[data-poll-until-value=pack_ready]"
    assert_select "[data-poll-until-value=posters]", count: 0
  end

  test "demo mode shows a single poster card and singular progress copy" do
    previous = ENV["POSTER_FORMAT_SET"]
    ENV["POSTER_FORMAT_SET"] = "demo"
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Just listed sa BGC")
    pack.generated_assets.create!(template_key: "just_listed", status: "rendering")

    get listing_path(listing)
    assert_response :success
    assert_match(/Creating poster/, response.body)
    assert_match(/Your branded graphic is on the way/, response.body)
    assert_match(/Branded square graphic for Facebook/, response.body)
    assert_select "h2", "Poster"
    assert_select "[data-controller=poster]", 1
    assert_no_match(/Queued/, response.body)
    assert_no_match(/Waiting/, response.body)
  ensure
    previous.nil? ? ENV.delete("POSTER_FORMAT_SET") : ENV["POSTER_FORMAT_SET"] = previous
  end

  test "ready pack with pending posters shows generating and waiting cards" do
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.user.update!(plan: "pro")
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Just listed sa BGC")
    pack.generated_assets.create!(template_key: "just_listed", status: "rendering")
    pack.generated_assets.create!(template_key: "price_card", status: "pending")
    pack.generated_assets.create!(template_key: "story", status: "pending")

    get listing_path(listing)
    assert_response :success
    assert_match(/Creating posters/, response.body)
    assert_match(/Generating/, response.body)
    assert_match(/Waiting|Queued/, response.body)
    assert_select "[data-controller=poll]"
    assert_select "[data-poll-until-value=posters]"
    assert_select "[data-poll-frame-value=listing_posters]"
    assert_select "turbo-frame#listing_posters"
    assert_select "h2", "Posters"
    assert_select "h2", text: "Building this pack", count: 0
  end

  test "ready pack uses copy tabs and download without a confirm step" do
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.user.update!(plan: "pro")
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Just listed sa BGC")
    GeneratedAsset::TEMPLATE_KEYS.each { |key| pack.generated_assets.create!(template_key: key) }

    get status_listing_content_packs_path(listing)
    assert_response :success
    assert_select "h2", "Captions and follow-ups"
    assert_select "button", "Post"
    assert_select "button", "Marketplace"
    assert_match "Waiting", response.body
    assert_no_match(/Confirm the asking price/, response.body)
    assert_match "text only", response.body
  end

  test "ready pack with a png offers enlarge and download" do
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Just listed sa BGC")
    asset = pack.generated_assets.create!(template_key: "just_listed")
    asset.image.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "poster.png", content_type: "image/png")
    GeneratedAsset::TEMPLATE_KEYS.reject { |key| key == "just_listed" }.each { |key| pack.generated_assets.create!(template_key: key) }

    get status_listing_content_packs_path(listing)
    assert_response :success
    assert_select "[data-controller=poster]"
    assert_select "button.poster-hit"
    assert_select "a", text: "Download PNG"
    assert_select "dialog[aria-labelledby]"
    assert_select "[data-poster-target=closeButton]"
  end

  test "ready listing show renders the pack inline, not a loading placeholder" do
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.user.update!(plan: "pro")
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Just listed sa BGC")
    asset = pack.generated_assets.create!(template_key: "just_listed")
    asset.image.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "poster.png", content_type: "image/png")
    GeneratedAsset::TEMPLATE_KEYS.reject { |key| key == "just_listed" }.each { |key| pack.generated_assets.create!(template_key: key) }

    get listing_path(listing)
    assert_response :success
    assert_no_match(/Loading pack/, response.body)
    assert_select "h2", "Posters"
    assert_select "a", text: "Download PNG"
    assert_select "[data-controller=poster]"
  end

  test "this week empty state includes a sample monday post" do
    sign_in users(:two)
    get weekly_calendars_path
    assert_response :success
    assert_select "h2", "No week generated yet"
    assert_select "p", /Monday/
  end

  test "this week confirm shows remaining packs instead of 1 of 3 cap" do
    user = users(:one)
    user.update!(quota_period_start: Time.zone.today.beginning_of_month, packs_count_in_period: 2)
    sign_in user

    get weekly_calendars_path
    assert_response :success
    assert_match(/You have 1 of 3 left this month/, response.body)
    assert_no_match(/This uses 1 of #{User::FREE_PACKS_PER_MONTH} free packs this month/, response.body)
  end

  test "this week with no credits links to plan instead of generate" do
    user = users(:one)
    user.update!(quota_period_start: Time.zone.today.beginning_of_month, packs_count_in_period: 3)
    sign_in user

    get weekly_calendars_path
    assert_response :success
    assert_select "a[href=?]", billing_path, text: /No packs left/
    assert_select "input[type=submit]", false
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

  test "edit listing offers delete with confirm" do
    sign_in users(:one)
    listing = listings(:bgc_condo)

    get edit_listing_path(listing)
    assert_response :success
    assert_select "button", text: "Delete listing"
    assert_match(/cannot be undone/i, response.body)

    assert_difference("Listing.count", -1) do
      delete listing_path(listing)
    end
    assert_redirected_to listings_path
  end

  test "ready pack with a stuck poster shows captions when poster rendering is disabled" do
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Just listed sa BGC")
    pack.generated_assets.create!(template_key: "just_listed", status: "rendering")

    with_env("POSTER_RENDERER" => "off") do
      get listing_path(listing)
    end

    assert_response :success
    assert_select "h2", "Captions and follow-ups"
    assert_match "Just listed sa BGC", response.body
    assert_match(/paused on this server/i, response.body)
    assert_no_match(/Creating poster/, response.body)
    assert_select "h2", text: "Building this pack", count: 0
  end

  test "redraw does not launch a render job when poster rendering is disabled" do
    sign_in users(:one)
    listing = listings(:bgc_condo)
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Just listed sa BGC")
    asset = pack.generated_assets.create!(template_key: "just_listed", status: "failed")

    with_env("POSTER_RENDERER" => "off") do
      assert_no_enqueued_jobs only: RenderAssetJob do
        post regenerate_listing_content_pack_generated_asset_path(listing, pack, asset)
      end
    end

    assert_redirected_to listing_path(listing)
    assert_equal "failed", asset.reload.status
    assert_match(/paused on this server/i, flash[:alert].to_s)
  end

  private
    def sign_in(user)
      post session_url, params: { email_address: user.email_address, password: "password" }
      follow_redirect!
    end
end
