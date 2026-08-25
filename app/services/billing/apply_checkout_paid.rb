class Billing::ApplyCheckoutPaid
  def initialize(checkout_session_id:, event_id:, event_type:, payload:)
    @checkout_session_id = checkout_session_id
    @event_id = event_id
    @event_type = event_type
    @payload = payload
  end

  def call
    return if BillingEvent.exists?(event_id: @event_id)

    user = User.find_by(paymongo_checkout_session_id: @checkout_session_id)
    user ||= User.find_by(id: @payload.dig("data", "attributes", "metadata", "user_id"))

    BillingEvent.create!(
      provider: "paymongo",
      event_id: @event_id,
      event_type: @event_type,
      user: user,
      payload: @payload,
      processed_at: Time.current
    )

    return unless user

    attrs = { plan: "pro" }
    customer_id = @payload.dig("data", "attributes", "payments", 0, "source", "id") ||
      @payload.dig("data", "relationships", "payments", "data", 0, "id")
    attrs[:paymongo_customer_id] = customer_id if customer_id.present?
    user.update!(attrs)
    BillingMailer.pro_receipt(user).deliver_later
  end
end
