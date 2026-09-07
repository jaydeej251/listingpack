module Ai
  # Optional vision step: sends photos.first to the AI for caption hints.
  # Set AI_PHOTO_VISION=off to skip (saves tokens; captions use listing fields only).
  # Default is on for OpenAI/OpenRouter; off for Ollama (gpt-oss is not a reliable vision model).
  class PhotoVision
    def self.mode
      ENV.fetch("AI_PHOTO_VISION", default_mode).downcase
    end

    def self.enabled?
      !%w[off false none 0 no].include?(mode)
    end

    def self.default_mode
      ollama_configured? ? "off" : "on"
    end

    def self.ollama_configured?
      ENV["OLLAMA_API_KEY"].to_s.strip.present? ||
        ENV["OPENAI_API_URL"].to_s.include?("ollama.com")
    end
  end
end
