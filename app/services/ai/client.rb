require "base64"
require "json"
require "net/http"
require "uri"

module Ai
  class Client
    class Error < StandardError; end

    def configured?
      api_key.present?
    end

    def chat(messages:, image_urls: [])
      raise Error, "OPENAI_API_KEY is not set" unless configured?

      content = messages
      if image_urls.any?
        content = [
          { role: "system", content: messages.first[:content] },
          {
            role: "user",
            content: [
              { type: "text", text: messages.last[:content] },
              *image_urls.map { |url| { type: "image_url", image_url: { url: url } } }
            ]
          }
        ]
      end

      body = {
        model: model,
        temperature: 0.6,
        response_format: { type: "json_object" },
        messages: content
      }

      uri = URI(chat_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)

      response = http.request(request)
      payload = JSON.parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, payload.dig("error", "message") || "AI request failed (#{response.code})"
      end

      text = payload.dig("choices", 0, "message", "content")
      usage = payload["usage"] || {}
      {
        text: text,
        model: payload["model"] || model,
        input_tokens: usage["prompt_tokens"],
        output_tokens: usage["completion_tokens"],
        raw: payload
      }
    end

    def data_uri_for(blob)
      "data:#{blob.content_type};base64,#{Base64.strict_encode64(blob.download)}"
    end

    private
      def api_key
        ENV["OPENAI_API_KEY"].presence
      end

      def model
        ENV.fetch("OPENAI_MODEL", "gpt-4o-mini")
      end

      def chat_url
        ENV.fetch("OPENAI_API_URL", "https://api.openai.com/v1/chat/completions")
      end
  end
end
