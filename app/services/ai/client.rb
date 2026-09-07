require "base64"
require "json"
require "net/http"
require "uri"

module Ai
  class Client
    class Error < StandardError; end

    OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"
    OPENROUTER_CHAT_URL = "https://openrouter.ai/api/v1/chat/completions"
    # OpenAI-compatible Cloud endpoint (see https://docs.ollama.com/cloud)
    OLLAMA_CHAT_URL = "https://ollama.com/v1/chat/completions"
    OPENAI_MODEL = "gpt-4o-mini"
    OPENROUTER_MODEL = "openai/gpt-4o-mini"
    OLLAMA_MODEL = "gpt-oss:20b"

    def configured?
      api_key.present?
    end

    def chat(messages:, image_urls: [])
      raise Error, "Set OLLAMA_API_KEY, OPENROUTER_API_KEY, or OPENAI_API_KEY" unless configured?

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
        messages: content
      }
      # gpt-oss / Ollama Cloud often returns blank content when response_format is set.
      # Default: on for OpenAI/OpenRouter; off for Ollama unless AI_JSON_OBJECT=on.
      body[:response_format] = { type: "json_object" } if json_object_format?
      body[:max_tokens] = max_output_tokens if max_output_tokens

      uri = URI(chat_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      if using_openrouter?
        request["HTTP-Referer"] = app_referer
        request["X-Title"] = "ListingPack"
      end
      request.body = JSON.generate(body)

      response = http.request(request)
      raw_body = response.body.to_s
      begin
        payload = raw_body.present? ? JSON.parse(raw_body) : {}
      rescue JSON::ParserError
        raise Error, "AI returned non-JSON body (#{response.code})"
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, payload.dig("error", "message") || "AI request failed (#{response.code})"
      end

      text = extract_message_text(payload)
      if text.blank?
        raise Error, "AI returned empty content (model=#{payload["model"] || model}). For Ollama Cloud try AI_JSON_OBJECT=off and AI_PHOTO_VISION=off."
      end

      usage = payload["usage"] || {}
      {
        text: text,
        model: payload["model"] || model,
        input_tokens: usage["prompt_tokens"] || usage["prompt_eval_count"],
        output_tokens: usage["completion_tokens"] || usage["eval_count"],
        raw: payload
      }
    end

    def data_uri_for(blob)
      "data:#{blob.content_type};base64,#{Base64.strict_encode64(blob.download)}"
    rescue ActiveStorage::FileNotFoundError
      nil
    end

    private
      def env_value(name)
        ENV[name].to_s.strip.presence
      end

      def api_key
        case provider
        when :ollama then env_value("OLLAMA_API_KEY") || env_value("OPENAI_API_KEY")
        when :openrouter then env_value("OPENROUTER_API_KEY") || env_value("OPENAI_API_KEY")
        when :openai then env_value("OPENAI_API_KEY")
        end
      end

      # Prefer an explicit Ollama key so a leftover OPENROUTER_API_KEY cannot steal traffic.
      def provider
        return :ollama if env_value("OLLAMA_API_KEY").present?
        return :ollama if ollama_url?(env_value("OPENAI_API_URL"))
        return :openrouter if env_value("OPENROUTER_API_KEY").present?
        return :openrouter if env_value("OPENAI_API_KEY")&.start_with?("sk-or-")
        return :openai if env_value("OPENAI_API_KEY").present?

        nil
      end

      def using_ollama?
        provider == :ollama
      end

      def using_openrouter?
        provider == :openrouter
      end

      def using_openai?
        provider == :openai
      end

      def ollama_url?(url)
        return false if url.blank?

        host = URI(url).host.to_s
        host.include?("ollama.com") || host.include?("api.ollama.com")
      rescue URI::InvalidURIError
        url.include?("ollama.com")
      end

      def chat_url
        explicit = env_value("OPENAI_API_URL")
        if explicit.present?
          # Ignore a leftover non-Ollama URL when OLLAMA_API_KEY selected the provider.
          return explicit unless using_ollama?
          return explicit if ollama_url?(explicit)
        end

        case provider
        when :ollama then OLLAMA_CHAT_URL
        when :openrouter then OPENROUTER_CHAT_URL
        else OPENAI_CHAT_URL
        end
      end

      def model
        explicit = env_value("OPENAI_MODEL")
        if explicit
          return normalize_openrouter_model(explicit) if using_openrouter?
          return explicit
        end

        case provider
        when :ollama then OLLAMA_MODEL
        when :openrouter then OPENROUTER_MODEL
        else OPENAI_MODEL
        end
      end

      def normalize_openrouter_model(name)
        name.include?("/") ? name : "openai/#{name}"
      end

      def app_referer
        AppHost.origin
      end

      def max_output_tokens
        value = env_value("AI_MAX_OUTPUT_TOKENS")
        return nil if value.blank?

        parsed = value.to_i
        parsed.positive? ? parsed : nil
      end

      def json_object_format?
        flag = env_value("AI_JSON_OBJECT")&.downcase
        return false if %w[off false 0 no].include?(flag)
        return true if %w[on true 1 yes].include?(flag)

        !using_ollama?
      end

      def extract_message_text(payload)
        message = payload.dig("choices", 0, "message") || payload["message"] || {}
        content = message["content"]
        text = normalize_content(content)
        # gpt-oss / Harmony sometimes parks the answer in reasoning while content is blank.
        text = normalize_content(message["reasoning"]) if text.blank?
        text = normalize_content(payload["response"]) if text.blank?
        text
      end

      def normalize_content(content)
        case content
        when String then content.strip.presence
        when Array
          content.filter_map { |part|
            next part.strip if part.is_a?(String)
            next unless part.is_a?(Hash)

            (part["text"] || part[:text]).to_s.strip.presence
          }.join.strip.presence
        else
          nil
        end
      end
  end
end
