module Ai
  # Optional vision step: sends photos.first to the AI for caption hints.
  # Set AI_PHOTO_VISION=off to skip (saves tokens; captions use listing fields only).
  class PhotoVision
    def self.mode
      ENV.fetch("AI_PHOTO_VISION", "on").downcase
    end

    def self.enabled?
      !%w[off false none].include?(mode)
    end
  end
end
