require "base64"
require "json"
require "net/http"
require "uri"

module Billing
  class Paymongo
    class Error < StandardError; end

    PRO_AMOUNT_CENTAVOS = 49_900 # ₱499.00

    def self.configured?
      ENV["PAYMONGO_SECRET_KEY"].present?
    end

    def initialize
      raise Error, "PAYMONGO_SECRET_KEY is not set" unless self.class.configured?
    end

    def create_checkout_session(user:)
      body = {
        data: {
          attributes: {
            send_email_receipt: true,
            show_description: true,
            show_line_items: true,
            description: "ListingPack Pro — unlimited packs, no watermark, Facebook share",
            line_items: [
              {
                currency: "PHP",
                amount: PRO_AMOUNT_CENTAVOS,
                name: "ListingPack Pro (1 month)",
                quantity: 1
              }
            ],
            payment_method_types: %w[gcash paymaya card],
            success_url: success_url,
            cancel_url: cancel_url,
            metadata: {
              user_id: user.id.to_s,
              email: user.email_address,
              plan: "pro"
            }
          }
        }
      }

      payload = request(:post, "/v2/checkout_sessions", body)
      data = payload.fetch("data")
      checkout_url = data.dig("attributes", "checkout_url")
      raise Error, "PayMongo did not return a checkout URL." if checkout_url.blank?

      {
        id: data.fetch("id"),
        checkout_url: checkout_url
      }
    end

    def retrieve_checkout_session(session_id)
      request(:get, "/v2/checkout_sessions/#{session_id}").fetch("data")
    end

    private
      def request(method, path, body = nil)
        uri = URI("https://api.paymongo.com#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request =
          case method
          when :post then Net::HTTP::Post.new(uri)
          when :get then Net::HTTP::Get.new(uri)
          else raise ArgumentError, "unsupported method"
          end
        request["Authorization"] = "Basic #{Base64.strict_encode64("#{secret_key}:")}"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body) if body

        response = http.request(request)
        payload = parse_json(response.body)

        unless response.is_a?(Net::HTTPSuccess)
          message = payload.dig("errors", 0, "detail") || "PayMongo request failed (#{response.code})"
          raise Error, message
        end

        payload
      end

      def parse_json(body)
        JSON.parse(body.to_s)
      rescue JSON::ParserError
        {}
      end

      def secret_key
        ENV.fetch("PAYMONGO_SECRET_KEY")
      end

      def success_url
        "#{AppHost.origin}/billing?paid=1"
      end

      def cancel_url
        "#{AppHost.origin}/billing?canceled=1"
      end
  end
end
