require "test_helper"

class Phase6PagesTest < ActionDispatch::IntegrationTest
  test "privacy terms guide and publishing are public" do
    get privacy_path
    assert_response :success
    assert_select "h1", "Privacy"

    get terms_path
    assert_response :success
    assert_select "h1", "Terms"

    get guide_path
    assert_response :success
    assert_select "h1", "How to ship a listing pack"

    get publishing_path
    assert_response :success
    assert_match(/Phase 9|Not unlocked/i, response.body)
  end

  test "admin failures requires admin" do
    sign_in users(:one)
    get admin_failures_path
    assert_redirected_to listings_path
  end

  test "admin can open failures" do
    user = users(:two)
    user.update!(admin: true)
    sign_in user
    get admin_failures_path
    assert_response :success
    assert_select "h1", "Failures"
  end

  test "admin can open another users listing from failures" do
    owner = users(:one)
    admin = users(:two)
    admin.update!(admin: true)
    listing = listings(:bgc_condo)
    listing.update!(status: "failed")

    sign_in admin
    get listing_path(listing)
    assert_response :success
    assert_match listing.title, response.body
  end

  test "non admin cannot open another users listing" do
    sign_in users(:two)
    get listing_path(listings(:bgc_condo))
    assert_response :not_found
  end

  test "paymongo webhook upgrades matching checkout" do
    user = users(:one)
    user.update!(plan: "free", paymongo_checkout_session_id: "cs_live_1")

    post paymongo_webhooks_path,
      params: {
        data: {
          id: "evt_webhook_1",
          attributes: {
            type: "checkout_session.payment.paid",
            data: { id: "cs_live_1" }
          }
        }
      },
      as: :json

    assert_response :success
    assert_equal "pro", user.reload.plan
  end

  private
    def sign_in(user)
      post session_url, params: { email_address: user.email_address, password: "password" }
      follow_redirect!
    end
end
