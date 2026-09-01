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
    assert_match(/Share from Listings/i, response.body)
    assert_match(/Pro Plus/i, response.body)
  end

  test "admin failures requires admin" do
    sign_in users(:one)
    get admin_failures_path
    assert_redirected_to listings_path
  end

  test "admin can open failures" do
    sign_in_operator users(:operator)
    get admin_failures_path
    assert_response :success
    assert_select "h1", "Failures"
  end

  test "admin can open another users listing from failures" do
    listing = listings(:bgc_condo)
    listing.update!(status: "failed")

    sign_in_operator users(:operator)
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

    def sign_in_operator(user)
      post admin_session_url, params: { email_address: user.email_address, password: "password" }
      follow_redirect!
    end
end
