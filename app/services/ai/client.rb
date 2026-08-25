require "base64"
require "json"
require "net/http"
require "uri"

module Ai
  class Client
    class Error < StandardError; end

    OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"
    OPENROUTER_CHAT_URL = "https://openrouter.ai/api/v1/chat/completions"
    OPENAI_MODEL = "gpt-4o-mini"
    OPENROUTER_MODEL = "openai/gpt-4o-mini"

    def configured?
      api_key.present?
    end

    def chat(messages:, image_urls: [])
      raise Error, "Set OPENROUTER_API_KEY or OPENAI_API_KEY" unless configured?

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
      if using_openrouter?
        request["HTTP-Referer"] = app_referer
        request["X-Title"] = "ListingPack"
      end
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
        ENV["OPENROUTER_API_KEY"].presence || ENV["OPENAI_API_KEY"].presence
      end

      def openrouter_credentials?
        ENV["OPENROUTER_API_KEY"].present? || api_key.to_s.start_with?("sk-or-")
      end

      def using_openrouter?
        openrouter_credentials? || chat_url.include?("openrouter.ai")
      end

      def chat_url
        return ENV["OPENAI_API_URL"] if ENV["OPENAI_API_URL"].present?

        openrouter_credentials? ? OPENROUTER_CHAT_URL : OPENAI_CHAT_URL
      end

      def model
        explicit = ENV["OPENAI_MODEL"].presence
        if explicit
          return normalize_openrouter_model(explicit) if using_openrouter?
          return explicit
        end

        using_openrouter? ? OPENROUTER_MODEL : OPENAI_MODEL
      end

      def normalize_openrouter_model(name)
        name.include?("/") ? name : "openai/#{name}"
      end

      def app_referer
        host = ENV["APP_HOST"].presence || "localhost:3000"
        return host if host.match?(/\Ahttps?:\/\//i)

        host.include?("localhost") ? "http://#{host}" : "https://#{host}"
      end
  end
end
