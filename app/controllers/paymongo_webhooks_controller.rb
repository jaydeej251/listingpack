class PaymongoWebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :verify_authenticity_token

  def create
    payload = JSON.parse(request.raw_post)
    event_id = payload.dig("data", "id")
    event_type = payload.dig("data", "attributes", "type") || payload.dig("data", "attributes", "event")

    if event_id.blank?
      head :bad_request
      return
    end

    if paid_checkout?(event_type, payload)
      checkout_id = checkout_session_id(payload)
      Billing::ApplyCheckoutPaid.new(
        checkout_session_id: checkout_id,
        event_id: event_id,
        event_type: event_type.to_s,
        payload: payload
      ).call
    else
      BillingEvent.find_or_create_by!(event_id: event_id) do |event|
        event.provider = "paymongo"
        event.event_type = event_type.to_s.presence || "unknown"
        event.payload = payload
        event.processed_at = Time.current
      end
    end

    head :ok
  rescue JSON::ParserError
    head :bad_request
  rescue ActiveRecord::RecordNotUnique
    head :ok
  end

  private
    def paid_checkout?(event_type, payload)
      type = event_type.to_s
      return true if type.include?("checkout_session") && type.include?("paid")
      return true if type == "checkout_session.payment.paid"

      status = payload.dig("data", "attributes", "data", "attributes", "status") ||
        payload.dig("data", "attributes", "status")
      status.to_s == "paid" && type.to_s.include?("checkout")
    end

    def checkout_session_id(payload)
      payload.dig("data", "attributes", "data", "id") ||
        payload.dig("data", "id")
    end
end
