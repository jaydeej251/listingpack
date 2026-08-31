require "test_helper"

class BillingPaymongoTest < ActiveSupport::TestCase
  test "apply checkout paid upgrades user once" do
    user = users(:one)
    user.update!(plan: "free", paymongo_checkout_session_id: "cs_test_123")

    payload = {
      "data" => {
        "id" => "evt_1",
        "attributes" => {
          "type" => "checkout_session.payment.paid",
          "data" => { "id" => "cs_test_123" },
          "metadata" => { "user_id" => user.id.to_s }
        }
      }
    }

    Billing::ApplyCheckoutPaid.new(
      checkout_session_id: "cs_test_123",
      event_id: "evt_1",
      event_type: "checkout_session.payment.paid",
      payload: payload
    ).call

    assert_equal "pro", user.reload.plan
    assert_equal 1, BillingEvent.count

    Billing::ApplyCheckoutPaid.new(
      checkout_session_id: "cs_test_123",
      event_id: "evt_1",
      event_type: "checkout_session.payment.paid",
      payload: payload
    ).call

    assert_equal 1, BillingEvent.count
  end

  test "creates checkout sessions on PayMongo v2" do
    user = users(:one)
    captured_path = nil
    success = fake_http_response("200", {
      "data" => {
        "id" => "cs_live_1",
        "attributes" => { "checkout_url" => "https://checkout.paymongo.com/cs_live_1" }
      }
    }.to_json)

    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:request) do |request|
      captured_path = request.path
      success
    end

    with_env("PAYMONGO_SECRET_KEY" => "sk_test_x", "APP_HOST" => "listingpack.test") do
      stub_singleton(Net::HTTP, :new, ->(*) { fake_http }) do
        session = Billing::Paymongo.new.create_checkout_session(user: user)

        assert_equal "/v2/checkout_sessions", captured_path
        assert_equal "cs_live_1", session[:id]
        assert_equal "https://checkout.paymongo.com/cs_live_1", session[:checkout_url]
      end
    end
  end

  test "surfaces a paymongo 404 as a readable error" do
    missing = fake_http_response("404", { "errors" => [ { "detail" => "Checkout sessions are only available on v2." } ] }.to_json)

    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:request) { |_| missing }

    with_env("PAYMONGO_SECRET_KEY" => "sk_test_x") do
      stub_singleton(Net::HTTP, :new, ->(*) { fake_http }) do
        error = assert_raises(Billing::Paymongo::Error) do
          Billing::Paymongo.new.create_checkout_session(user: users(:one))
        end
        assert_match(/v2/, error.message)
      end
    end
  end

  private
    def fake_http_response(code, body)
      Object.new.tap do |response|
        response.define_singleton_method(:body) { body }
        response.define_singleton_method(:code) { code }
        response.define_singleton_method(:is_a?) do |klass|
          code.to_i.between?(200, 299) && klass == Net::HTTPSuccess
        end
      end
    end
end
