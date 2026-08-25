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
end
