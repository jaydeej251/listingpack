require "base64"
require "json"
require "net/http"
require "securerandom"
require "uri"

module Ai
  # OpenAI Images API only — always uses OPENAI_IMAGE_API_KEY or OPENAI_API_KEY.
  # Independent from Ai::Client (Ollama/OpenRouter) so caption + beauty can split providers.
  class ImageClient
    class Error < StandardError; end

    EDITS_URL = "https://api.openai.com/v1/images/edits"
    DEFAULT_MODEL = "gpt-image-1.5"
    DEFAULT_SIZE = "1024x1024"
    DEFAULT_QUALITY = "medium"
    MAX_PHOTOS = 6

    def configured?
      key = api_key
      return false if key.blank?
      return false if openrouter_key?(key)
      # Dedicated image key always wins. Otherwise require an OpenAI-style sk- key so an
      # Ollama token sitting in OPENAI_API_KEY does not spam api.openai.com.
      return true if env_value("OPENAI_IMAGE_API_KEY").present?
      return true if key.start_with?("sk-")

      false
    end

    # Opt-in only. Default OFF so packs never hit OpenAI Images without explicit consent/credits.
    def enabled?
      return false unless configured?
      return false unless flag_on?("POSTER_BEAUTY")

      true
    end

    # images: array of hashes { filename:, content_type:, bytes: String }
    def edit(images:, prompt:, size: nil, quality: nil, model: nil)
      raise Error, "Set OPENAI_API_KEY (or OPENAI_IMAGE_API_KEY) for poster beauty" unless configured?
      raise Error, "At least one reference image is required" if images.blank?
      raise Error, "Prompt is required" if prompt.to_s.strip.blank?

      files = Array(images).first(max_photos)
      payload_model = model.presence || self.model
      payload_size = size.presence || self.size
      payload_quality = quality.presence || self.quality

      boundary = "----ListingPackBoundary#{SecureRandom.hex(16)}"
      body = String.new(encoding: Encoding::ASCII_8BIT)
      files.each_with_index do |file, index|
        filename = file[:filename].presence || "photo_#{index}.png"
        content_type = file[:content_type].presence || "image/png"
        bytes = file[:bytes]
        raise Error, "Image #{index} is empty" if bytes.blank?

        body << "--#{boundary}\r\n".b
        body << "Content-Disposition: form-data; name=\"image[]\"; filename=\"#{filename}\"\r\n".b
        body << "Content-Type: #{content_type}\r\n\r\n".b
        body << bytes.to_s.b
        body << "\r\n".b
      end
      {
        prompt: prompt.to_s,
        model: payload_model,
        size: payload_size,
        quality: payload_quality,
        n: "1"
      }.each do |key, value|
        body << "--#{boundary}\r\n".b
        body << "Content-Disposition: form-data; name=\"#{key}\"\r\n\r\n".b
        # Prompt may include ₱ / Taglish — force binary so it can join image bytes.
        body << value.to_s.encode("UTF-8").b
        body << "\r\n".b
      end
      body << "--#{boundary}--\r\n".b

      uri = URI(EDITS_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = read_timeout
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      request.body = body

      response = http.request(request)
      raw_body = response.body.to_s
      begin
        payload = raw_body.present? ? JSON.parse(raw_body) : {}
      rescue JSON::ParserError
        raise Error, "OpenAI Images returned non-JSON body (#{response.code})"
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, payload.dig("error", "message") || "OpenAI Images failed (#{response.code})"
      end

      b64 = payload.dig("data", 0, "b64_json")
      raise Error, "OpenAI Images returned no image data" if b64.blank?

      usage = payload["usage"] || {}
      {
        png_bytes: Base64.decode64(b64),
        model: payload_model,
        input_tokens: usage["input_tokens"],
        output_tokens: usage["output_tokens"],
        raw: payload
      }
    end

    def model
      env_value("OPENAI_IMAGE_MODEL") || DEFAULT_MODEL
    end

    def size
      env_value("OPENAI_IMAGE_SIZE") || DEFAULT_SIZE
    end

    def quality
      env_value("OPENAI_IMAGE_QUALITY") || DEFAULT_QUALITY
    end

    def max_photos
      value = env_value("POSTER_BEAUTY_MAX_PHOTOS")&.to_i
      value = MAX_PHOTOS if value.nil? || value <= 0
      [ value, 16 ].min
    end

    private
      def env_value(name)
        ENV[name].to_s.strip.presence
      end

      def api_key
        env_value("OPENAI_IMAGE_API_KEY") || env_value("OPENAI_API_KEY")
      end

      def openrouter_key?(key = api_key)
        key.to_s.start_with?("sk-or-")
      end

      def flag_off?(name)
        %w[off false 0 no].include?(env_value(name)&.downcase)
      end

      def flag_on?(name)
        %w[on true 1 yes].include?(env_value(name)&.downcase)
      end

      def read_timeout
        value = env_value("OPENAI_IMAGE_TIMEOUT").to_i
        value.positive? ? value : 180
      end
  end
end
