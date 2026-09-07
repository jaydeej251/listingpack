require "test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  setup do
    @agent = users(:one)
    @admin = users(:operator)
  end

  test "non admin cannot open users" do
    sign_in_agent @agent
    get admin_users_path
    assert_redirected_to listings_path
  end

  test "logged out admin pages go to operator login" do
    get admin_users_path
    assert_redirected_to admin_login_path
  end

  test "agent studio login does not show operator nav" do
    sign_in_agent @agent
    get listings_path
    assert_response :success
    assert_select "a", text: "Listings"
    assert_select "a", text: "Users", count: 0
    assert_select "a", text: "Failures", count: 0
  end

  test "studio login rejects operator accounts" do
    post session_url, params: { email_address: @admin.email_address, password: "password" }
    assert_redirected_to admin_login_path
    get admin_users_path
    assert_redirected_to admin_login_path
  end

  test "operator login rejects agent accounts" do
    post admin_session_url, params: { email_address: @agent.email_address, password: "password" }
    assert_redirected_to admin_login_path
    get admin_users_path
    assert_redirected_to admin_login_path
  end

  test "admin can search users and open a detail page" do
    sign_in_operator @admin
    get admin_users_path, params: { q: @agent.email_address }
    assert_response :success
    assert_select "h1", "Users"
    assert_match @agent.email_address, response.body
    assert_no_match @admin.email_address, response.body
    assert_select "a[href=?]", admin_user_path(@agent)

    get admin_user_path(@agent)
    assert_response :success
    assert_match @agent.email_address, response.body
    assert_match "Grant Pro", response.body
    assert_no_match "Make admin", response.body
  end

  test "admin grants pro with a reason and audit event" do
    @agent.update!(plan: "free")
    sign_in_operator @admin

    assert_difference -> { BillingEvent.where(provider: "admin", event_type: "grant_pro").count }, 1 do
      post grant_pro_admin_user_path(@agent), params: { reason: "PayMongo paid, webhook missing" }
    end
    assert_redirected_to admin_user_path(@agent)
    assert_equal "pro", @agent.reload.plan
    follow_redirect!
    assert_match "Granted Pro", response.body
    assert_match "PayMongo paid, webhook missing", response.body
  end

  test "grant pro without reason is rejected" do
    sign_in_operator @admin
    post grant_pro_admin_user_path(@agent), params: { reason: "" }
    assert_redirected_to admin_user_path(@agent)
    assert_equal "free", @agent.reload.plan
  end

  test "admin resets free quota" do
    @agent.update!(plan: "free", packs_count_in_period: 3, quota_period_start: Time.zone.today.beginning_of_month)
    sign_in_operator @admin
    post reset_quota_admin_user_path(@agent), params: { reason: "Failed pack ate a Free credit" }
    assert_redirected_to admin_user_path(@agent)
    assert_equal 0, @agent.reload.packs_count_in_period
  end

  test "admin viewing a free agents listing uses the agents plan for watermark copy" do
    listing = listings(:bgc_condo)
    listing.content_packs.create!(status: "ready", language: "taglish", stage: "listed")
    listing.update!(status: "ready")
    sign_in_operator @admin
    get listing_path(listing)
    assert_response :success
    assert_match "Viewing as admin", response.body
    assert_match "Free plans include a small ListingPack credit", response.body
    assert_no_match "Generate again", response.body
    assert_match "share from Listings is locked", response.body
    assert_select "a", text: "Listings", count: 0
  end

  test "admin cannot edit another users listing" do
    listing = listings(:bgc_condo)
    sign_in_operator @admin
    get edit_listing_path(listing)
    assert_redirected_to listing_path(listing)
  end

  test "admin cannot generate a pack as themselves on another users listing" do
    listing = listings(:bgc_condo)
    sign_in_operator @admin
    assert_no_enqueued_jobs only: GeneratePackJob do
      post listing_content_packs_path(listing)
    end
    assert_redirected_to listing_path(listing)
  end

  test "admin retry on another users failed listing enqueues a job" do
    listing = listings(:bgc_condo)
    listing.update!(status: "failed")
    sign_in_operator @admin

    assert_enqueued_with(job: GeneratePackJob) do
      post retry_listing_content_packs_path(listing)
    end
    assert_redirected_to listing_path(listing)
  end

  test "failures page links retry and users" do
    listing = listings(:bgc_condo)
    listing.update!(status: "failed")
    sign_in_operator @admin
    get admin_failures_path
    assert_response :success
    assert_select "a[href=?]", admin_users_path
    assert_select "a[href=?]", admin_user_path(@agent)
    assert_select "form[action=?]", retry_listing_content_packs_path(listing)
  end

  test "operators have no brand kit" do
    refute @admin.brand_kit.present?
  end

  private
    def sign_in_agent(user)
      post session_url, params: { email_address: user.email_address, password: "password" }
      follow_redirect!
    end

    def sign_in_operator(user)
      post admin_session_url, params: { email_address: user.email_address, password: "password" }
      follow_redirect!
    end
end
